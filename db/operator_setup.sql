-- Run as project operator in Supabase SQL Editor AFTER schema.sql.
-- This function is intentionally inaccessible to anon/authenticated clients.
create or replace function private.provision_agency(agency_name text, admin_phone text, admin_name text)
returns uuid language plpgsql security invoker set search_path='' as $$
declare uid uuid; aid uuid;
begin
 select id into uid from auth.users where phone=replace(admin_phone,'+','');
 if uid is null then raise exception '관리자가 먼저 문자 인증으로 가입해야 합니다.'; end if;
 if exists(select 1 from public.memberships where user_id=uid and active) then raise exception '이미 소속 기관이 있습니다.'; end if;
 insert into public.profiles(id,name) values(uid,admin_name) on conflict(id) do nothing;
 insert into public.agencies(name) values(agency_name) returning id into aid;
 insert into public.memberships(agency_id,user_id,role) values(aid,uid,'admin');
 return aid;
end $$;
revoke all on function private.provision_agency(text,text,text) from public,anon,authenticated;
-- Replace values yourself. This example is commented and never auto-executed.
-- select private.provision_agency('기관명', '+8210실제번호', '관리자 이름');
