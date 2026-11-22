"""Presentation contracts for the mobile and administrator Figma screens.

Callers must supply only RLS-visible rows. No invented device state or AI score.
"""
from datetime import datetime, timezone, timedelta
from backend.domain import parse_time, summarize

KST = timezone(timedelta(hours=9))
VISIT_LABELS = {'scheduled': '예정', 'active': '돌봄 중', 'paused': '쉬는 중', 'ended': '종료'}
CASE_LABELS = {'candidate': '확인 전', 'worker_pending': '지원사 답변 대기', 'agency_pending': '기관 답변 대기', 'complete': '검토 완료'}

def effective_events(events, corrections):
    result = [dict(e) for e in events]
    for c in sorted(corrections, key=lambda c: c.get('decided_at') or ''):
        if c['status'] == 'approved' and c['target'] == 'event':
            for e in result:
                if e['id'] == c['event_id']:
                    e['occurred_at'] = c['proposed']['occurred_at']
    return result

def local_date(stamp):
    return parse_time(stamp).astimezone(KST).date().isoformat() if stamp else None

def visit_card(v, data, now=None):
    events = sorted([e for e in data['visit_events'] if e['visit_id'] == v['id']], key=lambda e: e['seq'])
    changes = [c for c in data['corrections'] if c['visit_id'] == v['id']]
    effective = effective_events(events, changes)
    cases = [c for c in data['cases'] if c['visit_id'] == v['id']]
    schedule = next((s for s in data['schedules'] if s['id'] == v.get('schedule_id')), None)
    recipient = next((r for r in data['recipients'] if r['id'] == v['recipient_id']), {})
    worker = next((p for p in data.get('profiles', []) if p['id'] == v['worker_id']), {})
    state = v['state']
    status = ('worker_pending' if any(c['status'] == 'worker_pending' for c in cases) else
              'agency_pending' if any(c['status'] == 'agency_pending' for c in cases) else
              'candidate' if any(c['status'] == 'candidate' for c in cases) else
              'complete' if cases else 'none')
    return {**v, 'worker_name': worker.get('name'), 'recipient_name': recipient.get('name'),
            'address': recipient.get('address'), 'schedule': schedule,
            'state_label': VISIT_LABELS[state], 'review_status': status,
            'review_label': CASE_LABELS.get(status, '확인 요청 없음'),
            'original_events': events, 'effective_events': effective,
            'original_summary': summarize(events, now), 'summary': summarize(effective, now),
            'starts_at': effective[0]['occurred_at'] if effective else None,
            'ends_at': effective[-1]['occurred_at'] if effective and state == 'ended' else None,
            'pending_corrections': sum(c['status'] == 'pending' for c in changes),
            'date': local_date(effective[0]['occurred_at'] if effective else v.get('created_at'))}

def overview(data, day, now=None):
    cards = [visit_card(v, data, now) for v in data['visits']]
    today = [v for v in cards if v['date'] == day]
    visited = {v.get('schedule_id') for v in cards}
    planned = [s for s in data['schedules'] if local_date(s['starts_at']) == day and s['id'] not in visited]
    counts = {s: sum(v['state'] == s for v in today) for s in VISIT_LABELS}
    counts['scheduled'] += len(planned)
    return {'date': day, 'timezone': 'Asia/Seoul', 'visit_counts': counts,
            'review_counts': {s: sum(c['status'] == s for c in data['cases']) for s in CASE_LABELS},
            'pending_corrections': sum(c['status'] == 'pending' for c in data['corrections']),
            'pending_schedule_requests': sum(c['status'] == 'pending' for c in data['schedule_requests']),
            'visits': today, 'unstarted_schedules': planned,
            'notice': '확인 후보이며 부정수급 판정이 아닙니다.'}

def quality_records(data, now=None):
    now = now or datetime.now(timezone.utc)
    result = []
    for v in data['visits']:
        points = [p for p in data['locations'] if p['visit_id'] == v['id']]
        poor = [p for p in points if p['accuracy'] > 100]
        if not points:
            result.append({'visit_id': v['id'], 'type': 'location_unavailable', 'reason': '수신 위치 없음 · 권한 거부/통신 장애/시간만 기록 여부 확인', 'risk_score': None})
        elif poor:
            result.append({'visit_id': v['id'], 'type': 'gps_quality', 'reason': '일부 GPS 정확도 부족', 'excluded': len(poor), 'max_accuracy_m': max(p['accuracy'] for p in poor), 'risk_score': None})
        received = v.get('last_received_at')
        # Paused visits intentionally stop collection; silence is not device status.
        if v['state'] == 'active' and received and (now - parse_time(received)).total_seconds() > 300:
            result.append({'visit_id': v['id'], 'type': 'receipt_delay', 'reason': '최근 5분간 기록 수신 없음 · 현재 기기 상태는 알 수 없음', 'last_received_at': received, 'risk_score': None})
    return result
