from pathlib import Path
from datetime import datetime, timezone
import os
import secrets
from uuid import UUID

import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel, Field
from backend.domain import summarize
from backend.contracts import validate_command
from backend.readmodels import effective_events
from ai.detector import analyze, cross_visit_patterns

ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / '.env')
URL = os.getenv('SUPABASE_URL', '').rstrip('/')
KEY = os.getenv('SUPABASE_PUBLISHABLE_KEY', '')
app = FastAPI(title='동행이음', version='0.1.0')
app.mount('/static', StaticFiles(directory=ROOT/'backend/static'), name='static')
templates = Jinja2Templates(directory=ROOT/'backend/templates')

class Command(BaseModel):
    action: str
    payload: dict = Field(default_factory=dict)

async def remote(method, path, token=None, data=None, params=None):
    headers = {'apikey': KEY}
    if token: headers['Authorization'] = f'Bearer {token}'
    try:
        async with httpx.AsyncClient(timeout=25) as client:
            response = await client.request(method, URL+path, headers=headers, json=data, params=params)
    except httpx.HTTPError:
        raise HTTPException(503, '연결하지 못했습니다. 저장된 기록은 유지됩니다.')
    if response.is_error:
        try: detail = response.json().get('message') or response.json().get('msg')
        except ValueError: detail = None
        raise HTTPException(response.status_code if response.status_code < 500 else 502,
                            detail or '서버 요청을 처리하지 못했습니다.')
    return response.json() if response.content else {}

async def identity(request):
    authorization = request.headers.get('authorization')
    token = request.cookies.get('access_token')
    uses_bearer = authorization is not None
    if uses_bearer:
        parts = authorization.split()
        if len(parts) != 2 or parts[0].lower() != 'bearer':
            raise HTTPException(401, '올바른 로그인 인증이 필요합니다.')
        token = parts[1]
    if not token: raise HTTPException(401, '로그인이 필요합니다.')
    if request.method not in ('GET','HEAD') and not uses_bearer:
        csrf = request.cookies.get('csrf')
        if not csrf or not secrets.compare_digest(csrf,request.headers.get('x-csrf-token','')):
            raise HTTPException(403, '화면을 새로고침한 후 다시 시도하세요.')
    user = await remote('GET','/auth/v1/user',token)
    if not isinstance(user,dict) or not user.get('id'):
        raise HTTPException(401, '로그인을 다시 해주세요.')
    return token, user

async def administrator(request):
    token,user=await identity(request)
    memberships=await rows(token,'memberships',user_id=f"eq.{user['id']}",active='eq.true')
    if not memberships or memberships[0]['role']!='admin':
        raise HTTPException(403,'기관 관리자만 사용할 수 있습니다.')
    return token,user

async def rows(token, table, **filters):
    if 'limit' in filters:
        return await remote('GET',f'/rest/v1/{table}',token,params={'select':'*',**filters})
    result=[]
    for offset in range(0,10000,500):
        batch=await remote('GET',f'/rest/v1/{table}',token,params={'select':'*',**filters,'limit':500,'offset':offset,'order':filters.get('order','id.asc')})
        result.extend(batch)
        if len(batch)<500:return result
    raise HTTPException(413,'시험용 조회 범위를 초과했습니다. 날짜별 조회가 필요합니다.')

async def command(token, action, payload):
    return await remote('POST','/rest/v1/rpc/app_command',token,{'action':action,'payload':payload})

@app.middleware('http')
async def headers(request, call_next):
    origin=request.headers.get('origin')
    if request.method not in ('GET','HEAD','OPTIONS') and origin and origin!=str(request.base_url).rstrip('/'):
        return JSONResponse({'detail':'허용하지 않은 요청 출처입니다.'},status_code=403)
    response = await call_next(request)
    response.headers['Cache-Control']='no-store'
    response.headers['X-Content-Type-Options']='nosniff'
    response.headers['Referrer-Policy']='same-origin'
    response.headers['Content-Security-Policy']="default-src 'self'; style-src 'self'; script-src 'self'; img-src 'self' data:; frame-ancestors 'none'; base-uri 'self'"
    return response

@app.get('/health')
async def health(): return {'status':'ok','database':'not_checked'}

@app.get('/',response_class=HTMLResponse)
@app.get('/login',response_class=HTMLResponse)
async def page(request:Request):
    return templates.TemplateResponse(request=request,name='index.html',context={})

@app.get('/admin',response_class=HTMLResponse)
async def admin_page(request:Request):
    try:
        await administrator(request)
    except HTTPException as exc:
        if exc.status_code==401:
            return RedirectResponse('/login',status_code=303)
        raise
    return templates.TemplateResponse(request=request,name='index.html',context={})

@app.post('/auth/otp')
async def otp(request:Request):
    body=await request.json()
    phone=str(body.get('phone',''))
    if not phone.startswith('+') or not phone[1:].isdigit() or not 9 <= len(phone) <= 16:
        raise HTTPException(422,'국가번호를 포함한 전화번호를 입력하세요. 예: +821012345678')
    # SMS provider remains a deployment prerequisite. No mock success.
    return await remote('POST','/auth/v1/otp',data={'phone':phone,'create_user':True})

@app.post('/auth/verify')
async def verify(request:Request):
    body=await request.json()
    session=await remote('POST','/auth/v1/verify',data={'phone':body.get('phone'), 'token':body.get('token'),'type':'sms'})
    response=JSONResponse({'ok':True})
    secure=request.url.scheme=='https'
    response.set_cookie('access_token',session['access_token'],httponly=True,secure=secure,samesite='strict',max_age=session.get('expires_in',3600))
    response.set_cookie('csrf',secrets.token_urlsafe(24),secure=secure,samesite='strict',max_age=session.get('expires_in',3600))
    return response

@app.post('/auth/logout')
async def logout(request:Request):
    token,_=await identity(request)
    await remote('POST','/auth/v1/logout',token)
    response=JSONResponse({'ok':True})
    response.delete_cookie('access_token');response.delete_cookie('csrf')
    return response

@app.get('/api/bootstrap')
async def bootstrap(request:Request):
    token,user=await identity(request)
    profiles=await rows(token,'profiles',id=f"eq.{user['id']}")
    membership=await rows(token,'memberships',user_id=f"eq.{user['id']}",active='eq.true')
    result={'user_id':user['id'],'profile':profiles[0] if profiles else None,
            'membership':membership[0] if membership else None,
            'invitations':await rows(token,'invitations',user_id=f"eq.{user['id']}",status='eq.pending')}
    result['agencies']=await rows(token,'agencies')
    if membership:
        for name in ('recipients','assignments','schedules','schedule_requests','visits','cases','corrections'):
            result[name]=await rows(token,name)
        if membership[0]['role']=='admin':
            result['staff']=await rows(token,'profiles')
            result['memberships']=await rows(token,'memberships',active='eq.true')
    return result

@app.post('/api/command')
async def execute(request:Request,body:Command):
    token,_=await identity(request)
    if body.action not in {'profile','accept_invitation','invite','recipient','recipient_update','assign','schedule','schedule_update','schedule_request','decide_schedule','sync','note','correction','answer','question','review','close','decide'}:
        raise HTTPException(422,'지원하지 않는 작업입니다.')
    try:
        validate_command(body.action, body.payload)
    except (ValueError, TypeError, KeyError, AttributeError) as exc:
        raise HTTPException(422, f'입력 형식을 확인하세요: {exc}')
    if body.action=='sync' and (len(body.payload.get('events',[]))>500 or len(body.payload.get('locations',[]))>2000):
        raise HTTPException(413,'한 번에 전송할 기록 수를 초과했습니다.')
    return await command(token,body.action,body.payload)

@app.get('/api/visits/{visit_id}')
async def detail(request:Request,visit_id:UUID):
    token,_=await identity(request)
    found=await rows(token,'visits',id=f'eq.{visit_id}')
    if not found: raise HTTPException(404,'방문을 찾을 수 없습니다.')
    data={'visit':found[0]}
    for name in ('visit_events','locations','notes','cases','corrections'):
        data[name]=await rows(token,name,visit_id=f'eq.{visit_id}')
    data['summary']=summarize(data['visit_events'])
    effective=effective_events(data['visit_events'], data['corrections'])
    data['effective_events']=effective
    try: data['effective_summary']=summarize(effective)
    except (ValueError,KeyError): data['effective_summary']={'error':'승인 정정의 시간 순서를 확인하세요.'}
    return data

@app.post('/api/analyze/{visit_id}')
async def run_analysis(request:Request,visit_id:UUID):
    token,user=await identity(request)
    memberships=await rows(token,'memberships',user_id=f"eq.{user['id']}",active='eq.true')
    if not memberships or memberships[0]['role']!='admin': raise HTTPException(403,'기관 관리자만 분석할 수 있습니다.')
    data=await detail(request,visit_id)
    visit=data['visit']
    visit['duration']=data['summary']['care_seconds'] if visit['state']=='ended' else None
    # Do not label synthetic/training data as evaluated real-world AI accuracy.
    effective=effective_events(data['visit_events'],data['corrections'])
    visit['duration']=summarize(effective)['care_seconds'] if visit['state']=='ended' else None
    candidates=analyze(visit,effective,data['locations'])
    for candidate in candidates:
        await command(token,'candidate',{'visit_id':str(visit_id),**candidate})
    return {'candidates':candidates,'ai_status':'과거 유사 방문 학습 자료 연결 전 · 규칙/품질 점검만 수행'}

@app.get('/api/audit')
async def audit(request:Request):
    token,_=await administrator(request)
    return await rows(token,'audit_log',order='created_at.desc',limit='100')

@app.post('/api/analyze')
async def batch_analysis(request:Request):
    token,user=await identity(request)
    membership=await rows(token,'memberships',user_id=f"eq.{user['id']}",active='eq.true')
    if not membership or membership[0]['role']!='admin':raise HTTPException(403,'기관 관리자만 사용할 수 있습니다.')
    visits=await rows(token,'visits')
    events=await rows(token,'visit_events')
    points=await rows(token,'locations')
    schedules=await rows(token,'schedules')
    corrections=await rows(token,'corrections')
    events=effective_events(events,corrections)
    candidates=cross_visit_patterns(visits,events,schedules,corrections,points,datetime.now(timezone.utc))
    for v in visits:
        ve=[e for e in events if e['visit_id']==v['id']]
        vp=[p for p in points if p['visit_id']==v['id']]
        history=[]
        for old in visits:
            if old['id']==v['id'] or old['recipient_id']!=v['recipient_id'] or old['state']!='ended' or old['created_at']>=v['created_at']:continue
            op=[p for p in points if p['visit_id']==old['id']]
            if len(op)<10 or sum(p['accuracy']<=100 for p in op)/len(op)<.8:continue
            history.append({'duration':summarize([e for e in events if e['visit_id']==old['id']])['care_seconds']})
        v['duration']=summarize(ve)['care_seconds'] if v['state']=='ended' else None
        candidates.extend({'visit_id':v['id'],**x} for x in analyze(v,ve,vp,history))
    for candidate in candidates:await command(token,'candidate',candidate)
    return {'processed':len(visits),'candidates':len(candidates),'validated_accuracy':None}


class AdminLogin(BaseModel):
    email: str = Field(min_length=3, max_length=254)
    password: str = Field(min_length=1, max_length=1024)

@app.post('/auth/admin/login')
async def admin_login(request: Request, body: AdminLogin):
    session = await remote('POST', '/auth/v1/token?grant_type=password', data={'email': body.email.strip(), 'password': body.password})
    token = session.get('access_token')
    user = session.get('user', {})
    if not token or not user.get('id'):
        raise HTTPException(401, '로그인 응답을 확인할 수 없습니다.')
    members = await rows(token, 'memberships', user_id=f"eq.{user['id']}", active='eq.true')
    if not members or members[0]['role'] != 'admin':
        raise HTTPException(403, '기관에 등록된 관리자 계정이 필요합니다.')
    response = JSONResponse({'ok': True, 'role': 'admin'})
    secure = request.url.scheme == 'https'
    response.set_cookie('access_token', token, httponly=True, secure=secure, samesite='strict', max_age=session.get('expires_in',3600))
    response.set_cookie('csrf', secrets.token_urlsafe(24), secure=secure, samesite='strict', max_age=session.get('expires_in',3600))
    return response

from backend.screen_api import router as screen_router
app.include_router(screen_router)
