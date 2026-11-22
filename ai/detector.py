"""Explainable experimental candidates, never a fraud decision."""
from math import radians, sin, cos, atan2, sqrt
from statistics import median
from backend.domain import parse_time

VERSION = 'prototype-2026-11-21'

def distance(a, b):
    lat1, lat2 = radians(a['lat']), radians(b['lat'])
    dlat, dlon = lat2 - lat1, radians(b['lon'] - a['lon'])
    h = sin(dlat/2)**2 + cos(lat1)*cos(lat2)*sin(dlon/2)**2
    return 6371000 * 2 * atan2(sqrt(h), sqrt(max(0, 1-h)))

def analyze(visit, events, samples, history=(), config=None):
    cfg = {'max_accuracy': 100, 'gap_seconds': 300, 'home_radius': 150,
           'dwell_radius': 50, 'outside_seconds': 7200, 'dwell_seconds': 10800,
           'min_history': 20, **(config or {})}
    results = []
    def add(code, category, reason, first=None, last=None, evidence=None):
        results.append({'code': code, 'category': category, 'reason': reason,
                        'start_at': first, 'end_at': last, 'evidence': evidence or {},
                        'rule_version': VERSION})
    ordered_events = sorted(events, key=lambda e: e['seq'])
    def active_at(t):
        previous = [e for e in ordered_events if parse_time(e['occurred_at']) <= t]
        return bool(previous and previous[-1]['kind'] in ('start', 'resume'))
    good, rejected = [], 0
    for p in sorted(samples, key=lambda p: p['observed_at']):
        if p.get('accuracy', -1) < 0 or p['accuracy'] > cfg['max_accuracy']:
            rejected += 1
        elif active_at(parse_time(p['observed_at'])):
            good.append(p)
    if rejected or not good:
        add('quality', 'quality', '위치 자료가 부족하거나 정확도가 낮아 일부 경로 판단을 보류합니다.',
            evidence={'excluded': rejected, 'usable': len(good)})
    home = visit.get('home_snapshot') or {}
    segments, segment = [], []
    for p in good:
        if segment:
            a, b = parse_time(segment[-1]['observed_at']), parse_time(p['observed_at'])
            pause_between = any(a < parse_time(e['occurred_at']) <= b and e['kind'] in ('pause','end') for e in ordered_events)
            if (b-a).total_seconds() > cfg['gap_seconds'] or pause_between:
                if not pause_between and (b-a).total_seconds() > cfg['gap_seconds']:
                    add('collection_gap', 'quality', '돌봄 구간의 위치 수집 공백으로 해당 경로 판단을 보류합니다.', segment[-1]['observed_at'], p['observed_at'], {'gap_seconds': (b-a).total_seconds()})
                segments.append(segment); segment = []
        segment.append(p)
    if segment: segments.append(segment)
    for seg in segments:
        outside, dwell = [], []
        for p in seg:
            is_out = bool(home and distance(home, p) - p['accuracy'] > cfg['home_radius'])
            outside = outside + [p] if is_out else []
            if outside and (parse_time(p['observed_at'])-parse_time(outside[0]['observed_at'])).total_seconds() >= cfg['outside_seconds']:
                add('outside', 'rule', '거주지 밖 관측이 2시간 이상 이어졌습니다. 외출 지원 여부를 확인하세요.', outside[0]['observed_at'],p['observed_at'])
            if dwell and distance(dwell[0], p) > cfg['dwell_radius'] + dwell[0]['accuracy'] + p['accuracy']:
                dwell = []
            dwell.append(p)
            if (parse_time(p['observed_at'])-parse_time(dwell[0]['observed_at'])).total_seconds() >= cfg['dwell_seconds']:
                add('dwell', 'rule', '유사 위치 관측이 3시간 이상 이어졌습니다. 정상 재가 돌봄일 수도 있습니다.', dwell[0]['observed_at'], p['observed_at'])
    # Historical comparison excludes incomplete/poor-quality records upstream.
    durations = [float(x['duration']) for x in history if x.get('duration') is not None]
    if len(durations) >= cfg['min_history'] and visit.get('duration') is not None:
        from sklearn.ensemble import IsolationForest
        model = IsolationForest(random_state=42, contamination='auto').fit([[v] for v in durations])
        if model.predict([[visit['duration']]])[0] == -1:
            add('history', 'ai', '유사 방문의 기록 시간 패턴과 차이가 있습니다. 실제 사유를 확인하세요.',
                evidence={'samples':len(durations), 'median_seconds':median(durations),
                          'observed_seconds':visit['duration'], 'model':'IsolationForest', 'validated':False})
    if home and len(good)>=3:
        outside_flags=[distance(home,p)-p['accuracy']>cfg['home_radius'] for p in good]
        transitions=sum(1 for a,b in zip(outside_flags,outside_flags[1:]) if not a and b)
        if transitions>=3:
            add('repeated_exits','rule','거주지 경계 밖 관측이 반복되었습니다. 정상 외출·GPS 경계 오차를 확인하세요.',evidence={'count':transitions,'experimental':True})
        if not outside_flags[0] and not outside_flags[-1] and sum(outside_flags)/len(good)>.8:
            add('endpoints_home','rule','시작·종료 부근만 거주지에서 관측되었습니다. 외부 지원 사유를 확인하세요.',evidence={'experimental':True})
    unique = {}
    for r in results: unique[r['code']] = r
    return list(unique.values())

def cross_visit_patterns(visits,events,schedules,corrections,locations,now):
    """Time rules remain available even when GPS is absent."""
    out=[]
    schedule_by_id={s['id']:s for s in schedules}
    ordered=[]
    for v in visits:
        ev=sorted([e for e in events if e['visit_id']==v['id']],key=lambda e:e['seq'])
        if not ev: continue
        start=parse_time(ev[0]['occurred_at']); end=parse_time(ev[-1]['occurred_at']) if ev[-1]['kind']=='end' else now
        def add(code,category,reason,evidence=None):
            out.append({'visit_id':v['id'],'code':code,'category':category,'reason':reason,'start_at':start.isoformat(),'end_at':end.isoformat(),'evidence':evidence or {},'rule_version':VERSION})
        s=schedule_by_id.get(v.get('schedule_id'))
        if s:
            expected=(parse_time(s['ends_at'])-parse_time(s['starts_at'])).total_seconds()
            if v['state']=='ended' and abs((end-start).total_seconds()-expected)>1800:
                add('schedule_difference','rule','예정 시간과 기록 구간이 30분 이상 다릅니다. 일정 변경·기록 누락 여부를 확인하세요.',{'experimental':True,'threshold_seconds':1800})
            if v['state']!='ended' and now>parse_time(s['ends_at']) and (now-parse_time(s['ends_at'])).total_seconds()>1800:
                add('end_missing','quality','예정 종료 후 종료 기록을 받지 못했습니다. 오프라인 여부를 먼저 확인하세요.')
        if len([c for c in corrections if c['visit_id']==v['id']])>=3:
            add('repeated_corrections','operation','정정 요청이 반복됩니다. 입력 도움·교육이 필요한지 확인하세요.',{'experimental':True})
        ordered.append((v,start,end))
    for index,(v,start,end) in enumerate(ordered):
        for other,other_start,other_end in ordered[index+1:]:
            if other['worker_id']!=v['worker_id']:continue
            overlap=(min(end,other_end)-max(start,other_start)).total_seconds()
            if overlap>0:
                out.append({'visit_id':v['id'],'code':'overlap_'+other['id'],'category':'rule','reason':'동일 지원사의 두 방문 기록 구간이 겹칩니다.','start_at':max(start,other_start).isoformat(),'end_at':min(end,other_end).isoformat(),'evidence':{'other_visit':other['id'],'overlap_seconds':overlap},'rule_version':VERSION})
            previous,current=(v,other) if end<=other_start else (other,v)
            gap=(other_start-end).total_seconds() if end<=other_start else (start-other_end).total_seconds()
            p=sorted([x for x in locations if x['visit_id']==previous['id'] and 0<=x['accuracy']<=100],key=lambda x:x['observed_at'])
            q=sorted([x for x in locations if x['visit_id']==current['id'] and 0<=x['accuracy']<=100],key=lambda x:x['observed_at'])
            if gap>0 and p and q:
                elapsed=(parse_time(q[0]['observed_at'])-parse_time(p[-1]['observed_at'])).total_seconds()
                if elapsed>0 and distance(p[-1],q[0])/elapsed>55:
                    out.append({'visit_id':current['id'],'code':'travel_'+previous['id'],'category':'rule','reason':'방문 사이 관측 위치와 이동 시간이 일치하기 어렵습니다. 시각·GPS 오류를 먼저 확인하세요.','evidence':{'experimental':True,'speed_mps':round(distance(p[-1],q[0])/elapsed,1)},'rule_version':VERSION})
    return out
