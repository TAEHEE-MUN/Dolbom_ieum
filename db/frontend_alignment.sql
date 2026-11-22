-- Existing DB upgrade; preserves tables and original records. Remote application pending.
begin;
create or replace function private.command(action text, payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
 u uuid:=auth.uid(); a uuid; admin boolean; v public.visits; s public.schedules;
 r public.recipients; c public.cases; q public.corrections; inv public.invitations;
 e jsonb; old public.visit_events; prev public.visit_events; eid uuid; result jsonb;
 target_id uuid; wid uuid; stamp timestamptz; next_state text; snapshot jsonb; last_stamp timestamptz; sr public.schedule_requests;
begin
 if u is null then raise exception 'Authentication required' using errcode='42501'; end if;
 a:=private.my_agency(); admin:=private.is_admin();
 if action in ('recipient','recipient_update') and coalesce(payload->'home','{}'::jsonb)<>'{}'::jsonb then
   if jsonb_typeof(payload->'home')<>'object' or not ((payload->'home') ?& array['lat','lon'])
      or not coalesce((payload->'home'->>'lat')::float8 between -90 and 90,false)
      or not coalesce((payload->'home'->>'lon')::float8 between -180 and 180,false) then
     raise exception '거주지 위도·경도를 확인하세요.';
   end if;
 end if;
 if action='profile' then
   if length(trim(payload->>'name')) not between 1 and 80 then raise exception 'Name required'; end if;
   insert into public.profiles(id,name,consent_at) values(u,trim(payload->>'name'),case when (payload->>'consent')::boolean then now() end)
   on conflict(id) do update set name=excluded.name,consent_at=coalesce(public.profiles.consent_at,excluded.consent_at);
   return jsonb_build_object('ok',true);
 elsif action='accept_invitation' then
   select * into inv from public.invitations where id=(payload->>'id')::uuid and user_id=u and status='pending' for update;
   if inv.id is null or a is not null then raise exception 'Invitation unavailable or already linked'; end if;
   insert into public.memberships(agency_id,user_id,role) values(inv.agency_id,u,'worker');
   update public.invitations set status='accepted' where id=inv.id;
   return jsonb_build_object('ok',true);
 end if;
 if a is null then raise exception '기관 등록이 필요합니다.' using errcode='42501'; end if;
 if action='invite' and admin then
   select id into wid from public.profiles where link_code=(payload->>'code')::uuid;
   if wid is null or exists(select 1 from public.memberships where user_id=wid and active) then raise exception '연결 코드 확인 또는 기존 소속 정리가 필요합니다.'; end if;
   insert into public.invitations(agency_id,user_id) values(a,wid) returning to_jsonb(invitations.*) into result;
 elsif action='recipient' and admin then
   if length(trim(payload->>'name')) not between 1 and 80 then raise exception 'Name required'; end if;
   insert into public.recipients(agency_id,name,address,home) values(a,payload->>'name',coalesce(payload->>'address',''),coalesce(payload->'home','{}')) returning to_jsonb(recipients.*) into result;
 elsif action='recipient_update' and admin then
   select * into r from public.recipients where recipients.id=(payload->>'id')::uuid and agency_id=a for update;
   if r.id is null or r.version is distinct from (payload->>'version')::int then raise exception '최신 이용자 정보를 다시 확인하세요.'; end if;
   snapshot:=to_jsonb(r); target_id:=r.id;
   update public.recipients set address=payload->>'address',home=coalesce(payload->'home','{}'),version=version+1 where recipients.id=r.id returning to_jsonb(recipients.*) into result;
 elsif action='assign' and admin then
   if not exists(select 1 from public.recipients where id=(payload->>'recipient_id')::uuid and agency_id=a)
      or not exists(select 1 from public.memberships where user_id=(payload->>'worker_id')::uuid and agency_id=a and role='worker' and active) then raise exception '기관 범위가 올바르지 않습니다.'; end if;
   insert into public.assignments values((payload->>'recipient_id')::uuid,(payload->>'worker_id')::uuid) on conflict do nothing;
   result:='{"ok":true}';
 elsif action='schedule' and admin then
   if not exists(select 1 from public.assignments x join public.recipients y on y.id=x.recipient_id where x.recipient_id=(payload->>'recipient_id')::uuid and x.worker_id=(payload->>'worker_id')::uuid and y.agency_id=a)
      or not exists(select 1 from public.memberships where agency_id=a and user_id=(payload->>'worker_id')::uuid and active and role='worker') then raise exception '담당 이용자 연결이 필요합니다.'; end if;
   insert into public.schedules(agency_id,recipient_id,worker_id,starts_at,ends_at,break_minutes,memo)
   values(a,(payload->>'recipient_id')::uuid,(payload->>'worker_id')::uuid,(payload->>'starts_at')::timestamptz,(payload->>'ends_at')::timestamptz,coalesce((payload->>'break_minutes')::int,30),coalesce(payload->>'memo','')) returning to_jsonb(schedules.*) into result;
 elsif action='schedule_request' and not admin then
   select * into s from public.schedules where schedules.id=(payload->>'schedule_id')::uuid and agency_id=a and worker_id=u;
   if s.id is null or length(trim(coalesce(payload->>'reason','')))=0 then raise exception '배정 일정과 사유를 확인하세요.'; end if;
   if exists(select 1 from public.schedule_requests x where x.id=(payload->>'id')::uuid and
     (x.schedule_id<>s.id or x.requester_id<>u or x.proposed is distinct from payload->'proposed' or x.reason is distinct from payload->>'reason')) then
     raise exception '같은 요청 ID의 내용이 다릅니다.';
   end if;
   insert into public.schedule_requests(id,schedule_id,requester_id,proposed,reason) values((payload->>'id')::uuid,s.id,u,payload->'proposed',payload->>'reason') on conflict do nothing;
   result:='{"ok":true}'; target_id:=s.id;
 elsif action='decide_schedule' and admin then
   select * into sr from public.schedule_requests where schedule_requests.id=(payload->>'id')::uuid for update;
   select * into s from public.schedules where schedules.id=sr.schedule_id and agency_id=a for update;
   if s.id is null or sr.status<>'pending' or coalesce(payload->>'status','') not in ('approved','rejected') or length(trim(coalesce(payload->>'reason','')))=0 then raise exception '처리 상태와 사유를 확인하세요.'; end if;
   snapshot:=to_jsonb(s); target_id:=s.id;
   if payload->>'status'='approved' then
     update public.schedules set starts_at=(sr.proposed->>'starts_at')::timestamptz,ends_at=(sr.proposed->>'ends_at')::timestamptz,version=version+1 where schedules.id=s.id;
   end if;
   update public.schedule_requests set status=payload->>'status',decision_reason=payload->>'reason' where schedule_requests.id=sr.id;
   result:='{"ok":true}';
 elsif action='schedule_update' and admin then
   select * into s from public.schedules where schedules.id=(payload->>'id')::uuid and agency_id=a for update;
   if s.id is null or s.version is distinct from (payload->>'version')::int then raise exception '최신 일정을 다시 확인하세요.'; end if;
   snapshot:=to_jsonb(s); target_id:=s.id;
   update public.schedules set starts_at=(payload->>'starts_at')::timestamptz,ends_at=(payload->>'ends_at')::timestamptz,memo=coalesce(payload->>'memo',memo),version=version+1 where schedules.id=s.id returning to_jsonb(schedules.*) into result;
 elsif action='sync' and not admin then
   if not exists(select 1 from public.profiles where id=u and consent_at is not null) then raise exception '기록 안내 확인이 필요합니다.'; end if;
   target_id:=(payload->>'id')::uuid;
   perform pg_advisory_xact_lock(hashtextextended(u::text,0));
   select * into v from public.visits where visits.id=target_id for update;
   if v.id is null then
     select * into r from public.recipients where recipients.id=(payload->>'recipient_id')::uuid and agency_id=a;
     if r.id is null or not exists(select 1 from public.assignments where recipient_id=r.id and worker_id=u) then raise exception '배정된 이용자만 방문할 수 있습니다.'; end if;
     if payload->>'schedule_id' is not null then
       select * into s from public.schedules where schedules.id=(payload->>'schedule_id')::uuid and agency_id=a and worker_id=u and recipient_id=r.id;
       if s.id is null then raise exception '배정 일정 확인이 필요합니다.'; end if;
     elsif length(trim(coalesce(payload->>'temporary_reason','')))=0 then raise exception '임시 방문 사유가 필요합니다.'; end if;
     insert into public.visits(id,agency_id,worker_id,recipient_id,schedule_id,temporary,temporary_reason,home_snapshot)
     values(target_id,a,u,r.id,s.id,s.id is null,coalesce(payload->>'temporary_reason',''),r.home) returning * into v;
   end if;
   if v.agency_id<>a or v.worker_id<>u then raise exception '접근할 수 없는 방문입니다.' using errcode='42501'; end if;
   for e in select value from jsonb_array_elements(coalesce(payload->'events','[]')) order by (value->>'seq')::int loop
     eid:=(e->>'id')::uuid; stamp:=(e->>'occurred_at')::timestamptz;
     select * into old from public.visit_events where visit_events.id=eid;
     if old.id is not null then
       if old.visit_id<>target_id or old.seq<>(e->>'seq')::int or old.kind<>e->>'kind' or old.occurred_at<>stamp then raise exception '이벤트 원본은 변경할 수 없습니다.'; end if;
       continue;
     end if;
     select * into prev from public.visit_events where visit_id=target_id order by seq desc limit 1;
     if (e->>'seq')::int<>coalesce(prev.seq,0)+1 or stamp<prev.occurred_at or stamp>now()+interval '5 minutes' then raise exception '시각 또는 순번을 확인하세요.'; end if;
     next_state:=case when v.state='scheduled' and e->>'kind'='start' then 'active'
       when v.state='active' and e->>'kind'='pause' then 'paused'
       when v.state='paused' and e->>'kind'='resume' then 'active'
       when v.state in ('active','paused') and e->>'kind'='end' then 'ended' end;
     if next_state is null then raise exception '잘못된 방문 상태 전환입니다.'; end if;
     insert into public.visit_events(id,visit_id,seq,kind,occurred_at) values(eid,target_id,(e->>'seq')::int,e->>'kind',stamp);
     v.state:=next_state;
   end loop;
   for e in select value from jsonb_array_elements(coalesce(payload->'locations','[]')) loop
     stamp:=(e->>'observed_at')::timestamptz;
     select * into prev from public.visit_events where visit_id=target_id and occurred_at<=stamp order by seq desc limit 1;
     if prev.kind not in ('start','resume') or prev.id is null or stamp>now()+interval '5 minutes' then continue; end if;
     insert into public.locations(id,visit_id,observed_at,lat,lon,accuracy) values((e->>'id')::uuid,target_id,stamp,(e->>'lat')::float8,(e->>'lon')::float8,(e->>'accuracy')::float8) on conflict do nothing;
   end loop;
   update public.visits set state=v.state,last_received_at=now(),version=version+1 where visits.id=target_id returning to_jsonb(visits.*) into result;
 elsif action in ('note','correction','answer','question','review','close','decide','candidate') then
   if action in ('answer','question','review','close') then
     select * into c from public.cases where cases.id=(payload->>'id')::uuid for update;
     target_id:=c.visit_id;
   elsif action='decide' then
     select * into q from public.corrections where corrections.id=(payload->>'id')::uuid for update;
     target_id:=q.visit_id;
   else target_id:=(payload->>'visit_id')::uuid; end if;
   select * into v from public.visits where visits.id=target_id and agency_id=a for update;
   if v.id is null or (not admin and v.worker_id<>u) then raise exception '접근할 수 없습니다.' using errcode='42501'; end if;
   if action='note' then
     if exists(select 1 from public.notes n where n.id=(payload->>'id')::uuid and (n.visit_id<>target_id or n.author_id<>u or n.body<>payload->>'body')) then raise exception '같은 기록 ID의 내용이 다릅니다.'; end if;
     insert into public.notes(id,visit_id,author_id,body) values((payload->>'id')::uuid,target_id,u,payload->>'body') on conflict do nothing;
   elsif action='correction' and not admin then
     if length(trim(coalesce(payload->>'reason','')))=0 then raise exception '사유가 필요합니다.'; end if;
     if payload->>'target'='event' and not exists(select 1 from public.visit_events where visit_id=target_id and visit_events.id=(payload->>'event_id')::uuid) then raise exception '원본 이벤트 확인 필요'; end if;
     if exists(select 1 from public.corrections x where x.id=(payload->>'id')::uuid and
       (x.visit_id<>target_id or x.requester_id<>u or x.target is distinct from payload->>'target'
        or x.event_id is distinct from (payload->>'event_id')::uuid or x.proposed is distinct from payload->'proposed'
        or x.reason is distinct from payload->>'reason')) then raise exception '같은 요청 ID의 내용이 다릅니다.'; end if;
     insert into public.corrections(id,visit_id,requester_id,target,event_id,proposed,reason) values((payload->>'id')::uuid,target_id,u,payload->>'target',(payload->>'event_id')::uuid,payload->'proposed',payload->>'reason') on conflict do nothing;
   elsif action='candidate' and admin then
     insert into public.cases(visit_id,code,category,reason,evidence,start_at,end_at,rule_version)
     values(target_id,payload->>'code',payload->>'category',payload->>'reason',coalesce(payload->'evidence','{}'),(payload->>'start_at')::timestamptz,(payload->>'end_at')::timestamptz,payload->>'rule_version') on conflict(visit_id,code) do nothing;
   elsif action='question' and admin then
     if c.version is distinct from (payload->>'version')::int or c.status='complete' or length(trim(coalesce(payload->>'body','')))=0 then raise exception '최신 상태와 질문을 확인하세요.'; end if;
     snapshot:=to_jsonb(c);
     update public.cases set question=payload->>'body',worker_answer=null,agency_answer=null,result=null,status='worker_pending',version=version+1 where cases.id=c.id;
   elsif action='answer' and not admin then
     if c.status in ('agency_pending','complete') and c.worker_answer=payload->>'body' then return '{"ok":true}'; end if;
     if c.status<>'worker_pending' or c.version is distinct from (payload->>'version')::int or length(trim(coalesce(payload->>'body','')))=0 then raise exception '답변 대상/내용을 확인하세요.'; end if;
     update public.cases set worker_answer=payload->>'body',status='agency_pending',version=version+1 where cases.id=c.id;
   elsif action='review' and admin then
     if c.version is distinct from (payload->>'version')::int or c.status<>'agency_pending'
       or length(trim(coalesce(payload->>'body','')))=0 then raise exception '지원사 답변과 최신 검토 상태를 확인하세요.'; end if;
     snapshot:=to_jsonb(c);
     update public.cases set agency_answer=payload->>'body',result='needs_followup',version=version+1 where cases.id=c.id;
   elsif action='close' and admin then
     if c.version is distinct from (payload->>'version')::int or c.status<>'agency_pending' or c.worker_answer is null or length(trim(coalesce(payload->>'body','')))=0
       or coalesce(payload->>'result','') not in ('explained','corrected') or exists(select 1 from public.corrections where visit_id=target_id and status='pending') then raise exception '지원사 답변·기관 답변·정정 처리 완료가 필요합니다.'; end if;
     update public.cases set agency_answer=payload->>'body',result=payload->>'result',status='complete',version=version+1 where cases.id=c.id;
   elsif action='decide' and admin then
     if q.status<>'pending' or coalesce(payload->>'status','') not in ('approved','rejected') or length(trim(coalesce(payload->>'reason','')))=0 then raise exception '이미 처리되었거나 사유가 없습니다.'; end if;
     snapshot:=to_jsonb(q);
     if payload->>'status'='approved' and q.target='event' then
       if q.proposed->>'occurred_at' is null then raise exception '정정 시각이 필요합니다.'; end if;
       last_stamp:=null;
       for e in select jsonb_build_object('at',case when ev.id=q.event_id then q.proposed->>'occurred_at' else coalesce((select cr.proposed->>'occurred_at' from public.corrections cr where cr.event_id=ev.id and cr.status='approved' order by cr.decided_at desc limit 1),ev.occurred_at::text) end) from public.visit_events ev where ev.visit_id=target_id order by ev.seq loop
         stamp:=(e->>'at')::timestamptz;
         if stamp is null or stamp<last_stamp or stamp>now()+interval '5 minutes' then raise exception '정정 후 시간 순서가 올바르지 않습니다.'; end if;
         last_stamp:=stamp;
       end loop;
     elsif payload->>'status'='approved' and q.target='schedule' then
       select * into s from public.schedules where schedules.id=v.schedule_id for update;
       if s.id is null or (q.proposed->>'ends_at')::timestamptz<=(q.proposed->>'starts_at')::timestamptz then raise exception '정정할 일정과 시각을 확인하세요.'; end if;
       update public.schedules set starts_at=(q.proposed->>'starts_at')::timestamptz,ends_at=(q.proposed->>'ends_at')::timestamptz,version=version+1 where schedules.id=s.id;
     end if;
     -- Keep original event unchanged. Approved proposals form a separate effective-time layer.
     update public.corrections set status=payload->>'status',decision_reason=payload->>'reason',decided_by=u,decided_at=now() where corrections.id=q.id;
     insert into public.audit_log(agency_id,actor_id,action,entity_id,before_data) select a,u,'case_reopen',cases.id,to_jsonb(cases.*) from public.cases where visit_id=target_id and payload->>'status'='approved';
     update public.cases set status=case when question is null then 'candidate' else 'worker_pending' end,worker_answer=null,agency_answer=null,result=null,version=version+1 where visit_id=target_id and payload->>'status'='approved';
   else raise exception '역할에 허용되지 않은 작업입니다.' using errcode='42501'; end if;
   result:='{"ok":true}';
 else raise exception '허용되지 않은 작업입니다.' using errcode='42501'; end if;
 insert into public.audit_log(agency_id,actor_id,action,entity_id,before_data,after_data) values(a,u,action,target_id,snapshot,case when action='sync' then jsonb_build_object('state',v.state) else payload end);
 return result;
end $$;
commit;

-- Operator only: create the confirmed email/password user in Supabase Auth first.
create or replace function private.provision_agency_email(agency_name text, admin_email text, admin_name text)
returns uuid language plpgsql security invoker set search_path='' as $$
declare uid uuid; aid uuid;
begin
 if length(trim(coalesce(agency_name,'')))=0 or length(trim(coalesce(admin_name,'')))=0 then
   raise exception '기관명과 관리자 이름이 필요합니다.';
 end if;
 select id into uid from auth.users where lower(email)=lower(trim(admin_email));
 if uid is null then raise exception '먼저 Supabase Auth에 관리자 이메일 계정을 등록하세요.'; end if;
 if exists(select 1 from public.memberships where user_id=uid and active) then raise exception '이미 소속 기관이 있습니다.'; end if;
 insert into public.profiles(id,name) values(uid,admin_name) on conflict(id) do nothing;
 insert into public.agencies(name) values(agency_name) returning id into aid;
 insert into public.memberships(agency_id,user_id,role) values(aid,uid,'admin');
 return aid;
end $$;
revoke all on function private.provision_agency_email(text,text,text) from public,anon,authenticated;
