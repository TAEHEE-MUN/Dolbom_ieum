"""Screen-oriented API, using the current user's JWT and database RLS."""
from datetime import date, datetime, timezone
from uuid import UUID
from fastapi import APIRouter, HTTPException, Request, Query
from backend import main as core
from backend.readmodels import overview, visit_card, quality_records, local_date, KST, CASE_LABELS

router = APIRouter(prefix='/api/screens')

async def dataset(token):
    data = {}
    for name in ('profiles', 'memberships', 'recipients', 'assignments', 'schedules', 'schedule_requests',
                 'visits', 'visit_events', 'cases', 'corrections'):
        data[name] = await core.rows(token, name)
    return data

@router.get('/overview')
async def dashboard(request: Request, day: date | None = None):
    token, _ = await core.administrator(request)
    return overview(await dataset(token), (day or datetime.now(KST).date()).isoformat())

@router.get('/visits')
async def visits(request: Request, day: date | None = None, worker_id: UUID | None = None,
                 recipient_id: UUID | None = None, state: str | None = None,
                 temporary: bool | None = None, offset: int = Query(0, ge=0), limit: int = Query(50, ge=1, le=200)):
    token, _ = await core.identity(request)
    data = await dataset(token)
    result = [visit_card(v, data) for v in data['visits']]
    result = [v for v in result if (day is None or v['date'] == day.isoformat())
              and (worker_id is None or v['worker_id'] == str(worker_id))
              and (recipient_id is None or v['recipient_id'] == str(recipient_id))
              and (state is None or v['state'] == state)
              and (temporary is None or v['temporary'] == temporary)]
    result.sort(key=lambda v: v.get('starts_at') or v.get('created_at', ''), reverse=True)
    return {'items': result[offset:offset+limit], 'total': len(result), 'offset': offset}

@router.get('/cases')
async def cases(request: Request, category: str | None = None, status: str | None = None):
    token, _ = await core.identity(request)
    result = await core.rows(token, 'cases', order='created_at.desc')
    # Worker candidate privacy is enforced in RLS, including direct REST access.
    return {'items': [{**c, 'status_label': CASE_LABELS[c['status']]} for c in result
                      if (category is None or c['category'] == category) and (status is None or c['status'] == status)]}

@router.get('/cases/{case_id}')
async def case_detail(request: Request, case_id: UUID):
    token, _ = await core.identity(request)
    found = await core.rows(token, 'cases', id=f'eq.{case_id}')
    if not found:
        raise HTTPException(404, '확인 요청을 찾을 수 없습니다.')
    c = found[0]
    data = await core.detail(request, UUID(c['visit_id']))
    members = await core.rows(token, 'memberships', active='eq.true')
    _, user = await core.identity(request)
    admin = any(m['user_id'] == user['id'] and m['role'] == 'admin' for m in members)
    data['history'] = await core.rows(token, 'audit_log', entity_id=f"eq.{c['visit_id']}", order='created_at.asc') if admin else []
    pending = any(x['status'] == 'pending' for x in data['corrections'])
    data.update(case=c, can_submit_agency_review=admin and c['status'] == 'agency_pending' and bool(c.get('worker_answer')) and not pending,
                pending_corrections=pending, validated_accuracy=None)
    return data

@router.get('/requests')
async def requests(request: Request):
    token, _ = await core.identity(request)
    return {'corrections': await core.rows(token, 'corrections', order='created_at.desc'),
            'schedule_requests': await core.rows(token, 'schedule_requests', order='created_at.desc')}

@router.get('/corrections/{correction_id}')
async def comparison(request: Request, correction_id: UUID):
    token, _ = await core.identity(request)
    found = await core.rows(token, 'corrections', id=f'eq.{correction_id}')
    if not found:
        raise HTTPException(404, '정정 요청을 찾을 수 없습니다.')
    c = found[0]
    data = await core.detail(request, UUID(c['visit_id']))
    original = next((e for e in data['visit_events'] if e['id'] == c.get('event_id')), None)
    return {'correction': c, 'original_event': original, 'proposed': c['proposed'],
            'original_summary': data['summary'], 'effective_summary': data['effective_summary'],
            'visit': data['visit'], 'cases': data['cases']}

@router.get('/schedule')
async def schedule(request: Request, day: date | None = None):
    token, _ = await core.identity(request)
    result = await core.rows(token, 'schedules', order='starts_at.asc')
    return {'items': [s for s in result if day is None or local_date(s['starts_at']) == day.isoformat()], 'timezone': 'Asia/Seoul'}

@router.get('/people')
async def people(request: Request, search: str = ''):
    token, _ = await core.administrator(request)
    profiles = await core.rows(token, 'profiles')
    memberships = await core.rows(token, 'memberships', active='eq.true')
    workers = {m['user_id']: m for m in memberships if m['role'] == 'worker'}
    return {'workers': [{**p, 'membership': workers[p['id']]} for p in profiles if p['id'] in workers and search.casefold() in p['name'].casefold()],
            'recipients': await core.rows(token, 'recipients'), 'assignments': await core.rows(token, 'assignments')}

@router.get('/quality')
async def quality(request: Request):
    token, _ = await core.administrator(request)
    data = {'visits': await core.rows(token, 'visits'), 'locations': await core.rows(token, 'locations')}
    return {'items': quality_records(data), 'current_device_state': 'unknown', 'validated_accuracy': None}

@router.get('/settings')
async def settings(request: Request):
    token, _ = await core.administrator(request)
    from ai.detector import VERSION
    return {'agencies': await core.rows(token, 'agencies'),
            'administrators': await core.rows(token, 'memberships', active='eq.true', role='eq.admin'),
            'profiles': await core.rows(token, 'profiles'), 'rule_version': VERSION,
            'config_editable': False, 'retention_policy': None, 'sensor_collection_enabled': False,
            'notice': '설정 변경·보관 정책은 아직 확정되지 않았습니다.'}

@router.get('/mobile-home')
async def mobile_home(request: Request, day: date | None = None):
    token, user = await core.identity(request)
    data = await dataset(token)
    if not any(m['user_id'] == user['id'] and m['role'] == 'worker' and m['active'] for m in data['memberships']):
        raise HTTPException(403, '기관에 연결된 활동지원사만 사용할 수 있습니다.')
    day = (day or datetime.now(KST).date()).isoformat()
    cards = [visit_card(v, data) for v in data['visits']]
    return {'date': day, 'schedules': [s for s in data['schedules'] if local_date(s['starts_at']) == day],
            'visits': [v for v in cards if v['date'] == day or v['state'] in ('active', 'paused')],
            'requests': [c for c in data['cases'] if c['status'] == 'worker_pending'],
            'recipients': data['recipients'], 'profile': next((p for p in data['profiles'] if p['id'] == user['id']), None),
            'agencies': await core.rows(token, 'agencies')}
