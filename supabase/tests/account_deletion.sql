-- All fixtures are synthetic; every write is rolled back.
begin;
do $$declare u uuid:=gen_random_uuid(); peer uuid:=gen_random_uuid(); t uuid:=gen_random_uuid(); e uuid:=gen_random_uuid(); s uuid:=gen_random_uuid(); receipt text:=encode(extensions.gen_random_bytes(32),'hex');begin
 perform set_config('test.deleted',u::text,true); perform set_config('test.peer',peer::text,true);
 perform set_config('test.team',t::text,true); perform set_config('test.event',e::text,true);
 perform set_config('test.session',s::text,true); perform set_config('test.receipt',receipt,true);
 insert into auth.users(id,email,aud,role) values(u,u||'@example.invalid','authenticated','authenticated'),(peer,peer||'@example.invalid','authenticated','authenticated');
 insert into auth.sessions(id,user_id,created_at,updated_at) values(s,u,now()-interval '1 day',now());
 insert into public.teams(id,name,category,image,invite_code,members) values(t,'Deletion test','Skiing','',gen_random_uuid()::text,2);
 insert into public.profiles(id,role,birth_date,first_name,team_id) values(u,'coach','2000-01-01','Synthetic deleted',t),(peer,'athlete','2000-01-01','Synthetic peer',t);
 insert into public.team_memberships(team_id,user_id,role,status,is_manager,approved_by) values(t,u,'coach','active',true,u),(t,peer,'athlete','active',false,u);
 insert into public.training_sessions(user_id,date,sport_id,start_time,end_time,duration,effort,details) values(u,current_date,'running','09:00','10:00','60',5,'{"source":"health_sync"}'),(peer,current_date,'running','09:00','10:00','60',5,jsonb_build_object('coachId',u,'participants',jsonb_build_array(jsonb_build_object('athleteId',u,'name','Delete','hr',111),jsonb_build_object('athleteId',peer,'name','Keep','hr',123))));
 insert into public.body_metric_logs(user_id,date,type,value) values(u,current_date,'weight',70),(peer,current_date,'weight',80);
 insert into public.pr_logs(user_id,date,exercise_id,weight) values(u,current_date,'squat',100);
 insert into public.jump_logs(user_id,date,type,value) values(u,current_date,'cmj',30);
 insert into public.hrv_baselines(user_id,date,rmssd,device_source) values(u,current_date,50,'test');
 insert into public.health_consent_events(user_id,decision,notice_version) values(u,'granted','2026-10-04');
 insert into private.invite_attempts values(u,now(),1);
 insert into private.team_audit(team_id,actor_id,subject_id,action,next_state) values(t,peer,u,'synthetic',jsonb_build_object('user_id',u));
 insert into public.calendar_events(id,team_id,created_by,date,start_time,end_time,type,title,status,attendees,technical_details)
 values(e,t,u,current_date+1,'09:00','10:00','training','Synthetic shared','planned',jsonb_build_array(jsonb_build_object('id',u,'name','Delete','rpe',7),jsonb_build_object('id',peer,'name','Keep','rpe',5)),jsonb_build_object('workoutDraft',jsonb_build_object('ownerId',u,'participants',jsonb_build_array(jsonb_build_object('athleteId',u,'name','Delete'),jsonb_build_object('athleteId',peer,'name','Keep')))));
 insert into public.calendar_events(created_by,date,start_time,end_time,type,title,attendees) values(u,current_date,'08:00','09:00','training','Synthetic personal','[]');
 insert into public.notifications(user_id,title,message,timestamp) values(u,'Delete','Delete',now());
 insert into storage.objects(bucket_id,name,owner_id) values('avatars',u||'/synthetic.png',u::text);
 perform set_config('test.peer_notifications',(select count(*)::text from public.notifications where user_id=peer),true);
end $$;
set local role authenticated;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.deleted'),'role','authenticated','session_id',current_setting('test.session'))::text,true);
do $$begin
 begin
  perform public.request_account_deletion('ELIMINA',current_setting('test.receipt'));
  raise exception 'FAIL old session accepted';
 exception when insufficient_privilege then
  if sqlerrm not like 'Accedi di nuovo%' then raise; end if;
 end;
end $$;
reset role;
update auth.sessions set created_at=now() where id=current_setting('test.session')::uuid;
set local role authenticated;
do $$declare r jsonb;begin
 begin perform public.request_account_deletion('NO',current_setting('test.receipt'));raise exception 'FAIL confirmation bypass';exception when invalid_parameter_value then null;end;
 r:=public.request_account_deletion('ELIMINA',current_setting('test.receipt'));
 if r->>'status'<>'pending' then raise exception 'FAIL request'; end if;
 -- The same receipt is idempotent after sessions were revoked.
 r:=public.request_account_deletion('ELIMINA',current_setting('test.receipt'));
 if r->>'status'<>'pending' then raise exception 'FAIL idempotency'; end if;
 if private.account_is_active() then raise exception 'FAIL pending identity active';end if;
 begin insert into storage.objects(bucket_id,name,owner_id) values('avatars',auth.uid()||'/recreated.png',auth.uid()::text);raise exception 'FAIL stale JWT storage write';exception when insufficient_privilege then null;end;
 begin insert into public.profiles(id,role,birth_date) values(auth.uid(),'coach','2000-01-01');raise exception 'FAIL stale JWT profile write';exception when insufficient_privilege then null;end;
 begin perform public.claim_account_deletion(gen_random_uuid(),repeat('a',64));raise exception 'FAIL user worker access';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$declare u uuid:=current_setting('test.deleted')::uuid;peer uuid:=current_setting('test.peer')::uuid;t uuid:=current_setting('test.team')::uuid;e public.calendar_events;begin
 if exists(select 1 from public.profiles where id=u) or exists(select 1 from public.training_sessions where user_id=u) or exists(select 1 from public.body_metric_logs where user_id=u) or exists(select 1 from public.pr_logs where user_id=u) or exists(select 1 from public.jump_logs where user_id=u) or exists(select 1 from public.hrv_baselines where user_id=u) or exists(select 1 from public.health_consent_events where user_id=u) or exists(select 1 from public.notifications where user_id=u) or exists(select 1 from auth.sessions where user_id=u) or exists(select 1 from private.invite_attempts where user_id=u) or exists(select 1 from private.team_audit where subject_id=u or actor_id=u) then raise exception 'FAIL personal rows remain';end if;
 if (select count(*) from public.calendar_events where created_by=u)<>0 then raise exception 'FAIL creator';end if;
 select * into e from public.calendar_events where id=current_setting('test.event')::uuid;
 if e.id is null or e.created_by is not null or jsonb_array_length(e.attendees)<>1 or e.attendees->0->>'id'<>peer::text or e.technical_details::text like '%'||u||'%' then raise exception 'FAIL shared event scrub';end if;
 if (select count(*) from public.notifications where user_id=peer)::text<>current_setting('test.peer_notifications') then raise exception 'FAIL spurious notifications';end if;
 if not exists(select 1 from public.teams where id=t and members=1) or exists(select 1 from public.team_memberships where team_id=t and is_manager) or not exists(select 1 from public.profiles where id=peer) or not exists(select 1 from public.body_metric_logs where user_id=peer and value=80) or not exists(select 1 from public.training_sessions where user_id=peer and details->'participants'->0->>'name'='Keep' and details->'participants'->0->>'hr'='123') then raise exception 'FAIL last-manager/peer preservation';end if;
end $$;
set local role anon;
do $$declare r jsonb;begin
 r:=public.account_deletion_status(current_setting('test.receipt'));
 if r->>'status'<>'pending' or r ? 'user_id' or r ? 'email' then raise exception 'FAIL receipt status';end if;
 if public.account_deletion_status(repeat('b',64)) is not null then raise exception 'FAIL guessed receipt';end if;
 begin perform public.request_account_deletion('ELIMINA',repeat('c',64));raise exception 'FAIL anonymous deletion';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$declare j uuid; ticket text:=encode(extensions.gen_random_bytes(32),'hex');claim jsonb;begin
 select id into j from private.account_deletions where user_id=current_setting('test.deleted')::uuid;
 update private.account_deletions set ticket_hash=extensions.digest(ticket,'sha256'),ticket_expires_at=now()+interval '5 minutes' where id=j;
 if private.claim_account_deletion(j,repeat('d',64)) is not null then raise exception 'FAIL wrong ticket';end if;
 claim:=private.claim_account_deletion(j,ticket);
 if claim->>'user_id'<>current_setting('test.deleted') or jsonb_array_length(claim->'objects')<>1 then raise exception 'FAIL worker claim';end if;
 if private.claim_account_deletion(j,ticket) is not null then raise exception 'FAIL ticket replay';end if;
 begin perform private.finish_account_deletion(j,(claim->>'lease')::uuid);raise exception 'FAIL premature completion';exception when raise_exception then if sqlerrm<>'Cancellazione incompleta' then raise;end if;end;
 perform private.finish_account_deletion(j,(claim->>'lease')::uuid,'storage');
 if not exists(select 1 from private.account_deletions where id=j and status='pending' and next_attempt_at>now() and last_error='storage') then raise exception 'FAIL durable retry';end if;
 update private.account_deletions set ticket_hash=extensions.digest(ticket,'sha256'),ticket_expires_at=now()-interval '1 second' where id=j;
 if private.claim_account_deletion(j,ticket) is not null then raise exception 'FAIL expired ticket';end if;
end $$;
select 'Account deletion authorization, purge, peer preservation and retry checks passed' as verification;
rollback;
