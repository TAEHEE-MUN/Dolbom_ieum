from datetime import datetime, timezone
import httpx
import pytest
from backend import main
from backend.contracts import validate_command
from backend.readmodels import overview, quality_records, visit_card

ID = '00000000-0000-0000-0000-000000000001'
OTHER = '00000000-0000-0000-0000-000000000002'

def sample():
    return {'profiles': [{'id': ID, 'name': '지원사'}], 'memberships': [{'user_id': ID, 'role':'worker','active':True}],
            'recipients': [{'id': OTHER, 'name':'이용자'}], 'assignments': [],
            'visits':[{'id': ID, 'recipient_id':OTHER,'worker_id':ID,'schedule_id':None,'state':'ended','temporary':True,'created_at':'2026-11-22T23:59:00Z'}],
            'visit_events':[{'id':str(i),'visit_id':ID,'seq':i,'kind':kind,'occurred_at':stamp} for i,kind,stamp in
                [(1,'start','2026-11-23T00:00:00Z'),(2,'pause','2026-11-23T02:00:00Z'),(3,'resume','2026-11-23T02:30:00Z'),(4,'end','2026-11-23T04:30:00Z')]],
            'schedules':[], 'schedule_requests':[], 'cases':[], 'corrections':[]}

def test_summary_korea_date_and_no_case_is_not_completed_review():
    d=sample(); r=visit_card(d['visits'][0], d)
    assert r['date']=='2026-11-23'
    assert r['summary']['care_seconds']==14400
    assert r['summary']['break_seconds']==1800
    assert r['review_status']=='none'
    d['schedules']=[{'id':OTHER,'starts_at':'2026-11-22T23:00:00Z'}]
    result=overview(d,'2026-11-23')
    assert result['visit_counts']=={'scheduled':1,'active':0,'paused':0,'ended':1}

def test_original_and_approved_effective_values_separate():
    d=sample();d['corrections']=[{'visit_id':ID,'event_id':'4','target':'event','status':'approved','decided_at':'2026-11-23T05:00:00Z','proposed':{'occurred_at':'2026-11-23T05:00:00Z'}}]
    r=visit_card(d['visits'][0],d)
    assert r['original_summary']['care_seconds']==14400
    assert r['summary']['care_seconds']==16200
    assert d['visit_events'][-1]['occurred_at']=='2026-11-23T04:30:00Z'

def test_pause_not_receipt_delay_and_no_gps_not_stationary():
    d={'visits':[{'id':ID,'state':'paused','last_received_at':'2026-11-23T00:00:00Z'}],'locations':[]}
    q=quality_records(d,datetime(2026,11,23,2,tzinfo=timezone.utc))
    assert [x['type'] for x in q]==['location_unavailable']
    assert q[0]['risk_score'] is None

@pytest.mark.parametrize('action,payload',[
 ('close',{'id':ID,'version':1,'body':'   ','result':'explained'}),
 ('question',{'id':ID,'body':'질문'}),
 ('schedule_request',{'id':ID,'schedule_id':OTHER,'reason':'변경','proposed':{'starts_at':'2026-11-23T11:00:00Z','ends_at':'2026-11-23T10:00:00Z'}}),
 ('correction',{'id':ID,'visit_id':OTHER,'reason':'정정','target':'event','event_id':ID,'proposed':{'occurred_at':'2026-11-23T10:00:00'}}),
 ('sync',{'id':ID,'recipient_id':OTHER,'temporary_reason':'임시','events':{}}),
])
def test_invalid_writes_rejected(action,payload):
    with pytest.raises((ValueError,TypeError)):validate_command(action,payload)

@pytest.mark.asyncio
async def test_email_login_admin_membership_and_secure_cookie(monkeypatch):
    calls=[]
    async def remote(method,path,token=None,data=None,**kw):
        calls.append(path)
        return {'access_token':'access','user':{'id':ID},'expires_in':3600}
    role='worker'
    async def rows(*args,**kw):return [{'role':role}]
    monkeypatch.setattr(main,'remote',remote);monkeypatch.setattr(main,'rows',rows)
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=main.app),base_url='https://test') as c:
        body={'email':'admin@example.com','password':'test'}
        response=await c.post('/auth/admin/login',json=body)
        assert response.status_code==403 and 'set-cookie' not in response.headers
        role='admin'
        response=await c.post('/auth/admin/login',json=body)
        assert response.status_code==200
        cookies=response.headers.get_list('set-cookie')
        assert any('HttpOnly' in x and 'Secure' in x for x in cookies)
        assert '/auth/v1/token?grant_type=password' in calls

@pytest.mark.asyncio
async def test_screen_routes_no_auth_denied():
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=main.app),base_url='http://test') as c:
        for route in ['overview','visits','cases','requests','schedule','people','quality','settings','mobile-home',f'cases/{ID}',f'corrections/{ID}']:
            assert (await c.get('/api/screens/'+route)).status_code==401, route

@pytest.mark.asyncio
async def test_screen_queries_filters_and_worker_cannot_read_admin(monkeypatch):
    d=sample()
    async def remote(method,path,token=None,**kw):return {'id':ID}
    async def rows(token,table,**filters):
        if table=='memberships':return [{'user_id':ID,'role':'admin' if token=='admin' else 'worker','active':True}]
        return d.get(table,[])
    monkeypatch.setattr(main,'remote',remote);monkeypatch.setattr(main,'rows',rows)
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=main.app),base_url='http://test',headers={'Authorization':'Bearer worker'}) as c:
        for route in ['overview','people','quality','settings']:
            assert (await c.get('/api/screens/'+route)).status_code==403
        assert (await c.get('/api/screens/visits?state=active')).json()['total']==0
        assert (await c.get('/api/screens/visits?day=2026-11-23')).json()['total']==1
        assert (await c.get('/api/screens/overview?day=2026-11-23',headers={'Authorization':'Bearer admin'})).json()['visit_counts']['ended']==1

@pytest.mark.asyncio
async def test_validation_happens_before_rpc(monkeypatch):
    async def identity(request):return 'token',{'id':ID}
    async def command(*args):pytest.fail('invalid payload reached DB')
    monkeypatch.setattr(main,'identity',identity);monkeypatch.setattr(main,'command',command)
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=main.app),base_url='http://test') as c:
        assert (await c.post('/api/command',json={'action':'close','payload':{}})).status_code==422
