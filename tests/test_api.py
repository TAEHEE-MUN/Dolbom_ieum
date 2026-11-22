import pytest
import httpx
from backend.main import app
import backend.main as main

@pytest.mark.asyncio
async def test_admin_page_requires_valid_admin(monkeypatch):
    async def remote(method,path,token=None,**kwargs):
        if token=='invalid': raise main.HTTPException(401,'expired')
        return {'id':'verified-user'}
    async def rows(token,table,**filters):
        return [{'role':'admin' if token=='admin-token' else 'worker'}]
    monkeypatch.setattr(main,'remote',remote)
    monkeypatch.setattr(main,'rows',rows)
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app),base_url='http://test') as c:
        assert (await c.get('/admin')).status_code==303
        assert (await c.get('/admin',headers={'Authorization':'Bearer invalid'})).status_code==303
        assert (await c.get('/admin',headers={'Authorization':'Bearer worker-token'})).status_code==403
        assert (await c.get('/admin',headers={'Authorization':'Bearer admin-token'})).status_code==200
        assert (await c.get('/api/audit',headers={'Authorization':'Bearer worker-token'})).status_code==403

@pytest.mark.asyncio
async def test_cookie_csrf_cannot_be_bypassed_by_malformed_header(monkeypatch):
    async def remote(*args,**kwargs):
        pytest.fail('invalid auth must not reach Supabase')
    monkeypatch.setattr(main,'remote',remote)
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app),base_url='http://test',cookies={'access_token':'cookie-token','csrf':'expected'}) as c:
        body={'action':'profile','payload':{'name':'test'}}
        assert (await c.post('/api/command',json=body)).status_code==403
        assert (await c.post('/api/command',json=body,headers={'Authorization':'Basic malformed'})).status_code==401
        assert (await c.post('/api/command',json=body,headers={'Authorization':'Bearer '})).status_code==401
        assert (await c.post('/api/command',json=body,headers={'Origin':'https://other.example','X-CSRF-Token':'expected'})).status_code==403

@pytest.mark.asyncio
async def test_unauthenticated_records_denied():
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app),base_url='http://test') as c:
        assert (await c.get('/api/bootstrap')).status_code==401
        assert (await c.post('/api/command',json={'action':'schedule','payload':{}})).status_code==401

@pytest.mark.asyncio
async def test_web_shell_security_headers():
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app),base_url='http://test') as c:
        r=await c.get('/')
        assert r.status_code==200
        assert 'frame-ancestors' in r.headers['content-security-policy']
        assert r.headers['cache-control']=='no-store'
        assert (await c.get('/static/app.js')).status_code==200
