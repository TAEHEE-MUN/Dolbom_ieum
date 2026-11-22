"""Pure visit rules. Original device timestamps remain immutable."""
from datetime import datetime, timezone

TRANSITIONS = {
    'scheduled': {'start': 'active'},
    'active': {'pause': 'paused', 'end': 'ended'},
    'paused': {'resume': 'active', 'end': 'ended'},
    'ended': {},
}

def parse_time(value):
    result = datetime.fromisoformat(str(value).replace('Z', '+00:00'))
    if result.tzinfo is None:
        raise ValueError('시간대가 포함된 시각이 필요합니다.')
    return result

def summarize(events, now=None):
    state, start, previous, active, paused = 'scheduled', None, None, 0.0, 0.0
    seen = set()
    for event in sorted(events, key=lambda e: e['seq']):
        if event['seq'] in seen:
            raise ValueError('이벤트 순번이 중복되었습니다.')
        seen.add(event['seq'])
        stamp = parse_time(event['occurred_at'])
        kind = event['kind']
        if kind not in TRANSITIONS[state] or (previous and stamp < previous):
            raise ValueError('방문 상태 또는 시각 순서가 올바르지 않습니다.')
        if previous:
            seconds = (stamp - previous).total_seconds()
            active += seconds if state == 'active' else 0
            paused += seconds if state == 'paused' else 0
        start = start or stamp
        state, previous = TRANSITIONS[state][kind], stamp
    if previous and state != 'ended':
        seconds = max(0, ((now or datetime.now(timezone.utc)) - previous).total_seconds())
        active += seconds if state == 'active' else 0
        paused += seconds if state == 'paused' else 0
    return {'state': state, 'care_seconds': round(active), 'break_seconds': round(paused),
            'total_seconds': round(active + paused)}

def can_close(worker_answer, agency_answer, result, pending_corrections):
    return bool(worker_answer and agency_answer and result in ('explained', 'corrected')
                and not pending_corrections)
