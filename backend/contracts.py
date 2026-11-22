"""Validate write payloads before RPC; DB remains the authorization authority."""
from uuid import UUID
from backend.domain import parse_time

def validate_command(action, p):
    def uid(key, obj=p):
        UUID(str(obj.get(key, '')))
    def text(key, maximum=2000, obj=p):
        value = obj.get(key)
        if not isinstance(value, str) or not 1 <= len(value.strip()) <= maximum:
            raise ValueError(f'{key}: 필수 내용과 길이를 확인하세요.')
    def version():
        if type(p.get('version')) is not int or p['version'] < 1:
            raise ValueError('최신 version이 필요합니다.')
    def interval(obj):
        if parse_time(obj.get('ends_at')) <= parse_time(obj.get('starts_at')):
            raise ValueError('종료 시각은 시작 시각 이후여야 합니다.')
    if action == 'profile':
        text('name', 80)
    if action in ('accept_invitation', 'schedule_update', 'recipient_update', 'decide_schedule', 'answer', 'question', 'review', 'close', 'decide'):
        uid('id')
    if action in ('schedule_update', 'recipient_update', 'question', 'answer', 'review', 'close'):
        version()
    if action in ('note', 'answer', 'question', 'review', 'close'):
        text('body')
    if action in ('schedule_request', 'correction', 'decide_schedule', 'decide'):
        text('reason')
    if action in ('decide_schedule', 'decide') and p.get('status') not in ('approved', 'rejected'):
        raise ValueError('승인 또는 반려 상태가 필요합니다.')
    if action == 'close' and p.get('result') not in ('explained', 'corrected'):
        raise ValueError('검토 결과를 선택하세요.')
    if action in ('schedule', 'assign'):
        uid('worker_id'); uid('recipient_id')
    if action in ('schedule', 'schedule_update'):
        interval(p)
    if action == 'schedule_request':
        uid('id'); uid('schedule_id'); interval(p.get('proposed', {}))
    if action in ('note', 'correction'):
        uid('id'); uid('visit_id')
    if action == 'correction':
        if p.get('target') == 'event':
            uid('event_id'); parse_time(p.get('proposed', {}).get('occurred_at'))
        elif p.get('target') == 'schedule':
            interval(p.get('proposed', {}))
        else:
            raise ValueError('이벤트 시각 또는 일정 정정만 지원합니다.')
    if action == 'sync':
        uid('id'); uid('recipient_id')
        if p.get('schedule_id'):
            uid('schedule_id')
        else:
            text('temporary_reason')
        for key in ('events', 'locations'):
            if not isinstance(p.get(key, []), list):
                raise ValueError(f'{key}: 배열이 필요합니다.')
        for e in p.get('events', []):
            uid('id', e); parse_time(e.get('occurred_at'))
            if type(e.get('seq')) is not int or e['seq'] < 1 or e.get('kind') not in ('start','pause','resume','end'):
                raise ValueError('이벤트 순번과 상태를 확인하세요.')
        for point in p.get('locations', []):
            uid('id', point); parse_time(point.get('observed_at'))
            if not (-90 <= float(point['lat']) <= 90 and -180 <= float(point['lon']) <= 180 and 0 <= float(point['accuracy']) < float('inf')):
                raise ValueError('위치 좌표와 정확도를 확인하세요.')
