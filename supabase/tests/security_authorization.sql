-- Isolated synthetic identities. Every write is rolled back. No real health data.
begin;
do $$declare label text; u uuid;begin
 foreach label in array array['manager','coach','outsider','athlete','peer','other_athlete'] loop
   u:=gen_random_uuid(); perform set_config('test.'||label,u::text,true);
   insert into auth.users(id,email,aud,role) values(u,u::text||'@example.invalid','authenticated','authenticated');
   insert into public.profiles(id,first_name,last_name,email,birth_date,role)
     values(u,'Synthetic',label,u::text||'@example.invalid',date '2000-01-01',case when label in ('manager','coach','outsider') then 'coach' else 'athlete' end);
 end loop;
 insert into storage.objects(bucket_id,name,owner_id) values('avatars',current_setting('test.athlete')||'/synthetic.png',current_setting('test.athlete')),
 ('avatars',current_setting('test.other_athlete')||'/synthetic.png',current_setting('test.other_athlete'));
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub',current_setting('test.manager'),true);
do $$declare r jsonb;begin
 r:=public.team_operation('create',payload=>' {"name":"Synthetic team A"}'::jsonb);
 perform set_config('test.team',r->>'team_id',true);
end $$;
-- Save the invitation securely inside this test transaction.
select set_config('test.code',(select x->>'invite_code' from public.get_my_teams() x limit 1),true);
select set_config('request.jwt.claim.sub',current_setting('test.athlete'),true);
do $$declare r jsonb;begin
 r:=public.team_operation('join',payload=>jsonb_build_object('code',current_setting('test.code')));
 if r->>'status'<>'active' then raise exception 'FAIL athlete join'; end if;
 insert into public.body_metric_logs(user_id,date,type,value) values(auth.uid(),current_date,'weight',70);
 insert into public.training_sessions(user_id,sport_id,date,start_time,end_time,duration,effort,details)
 values(auth.uid(),'alpine_skiing',current_date,'09:00','10:00','01:00:00',5,
 '{"specialties":["SL","GS"],"tracks":[{"specialty":"SL","laps":2,"gates":30},{"specialty":"GS","laps":3,"gates":20}],"freeSkiingBySpecialty":{"SL":{"laps":2,"changes":10},"GS":{"laps":1,"changes":5}},"trainingBlocks":[{"specialty":"SX","laps":2,"references":4}],"notes":"never in leaderboard","avg_hr":145}'::jsonb);
 insert into public.training_sessions(user_id,sport_id,date,start_time,end_time,duration,effort,details)
 values(auth.uid(),'running',current_date,'10:00','11:00','01:00:00',5,'{"source":"health_sync","hr_zones_seconds":[0,0,1200,600,300,0],"heart_rate_samples":[145,146]}'::jsonb);
 insert into public.training_sessions(user_id,sport_id,date,start_time,end_time,duration,effort,details)
 values(auth.uid(),'alpine_skiing',current_date,'09:00','10:00','01:00:00',5,'{"tracks":[{"specialty":"SG","laps":2,"gates":40},{"specialty":"DH","laps":1,"gates":10},{"specialty":"SX","laps":4,"gates":5}]}');
 insert into public.training_sessions(user_id,sport_id,date,start_time,end_time,duration,effort,details)
 values(auth.uid(),'dryland_strength',current_date,'09:00','10:00','30',5,'{"exercises":[{"sets":[{"kg":40,"reps":10},{"kg":50,"reps":5}]}]}');
end $$;
select set_config('request.jwt.claim.sub',current_setting('test.peer'),true);
do $$declare n integer; r jsonb; denied boolean:=false;begin
 perform public.team_operation('join',payload=>jsonb_build_object('code',current_setting('test.code')));
 select count(*) into n from public.body_metric_logs where user_id=current_setting('test.athlete')::uuid;
 if n<>0 then raise exception 'FAIL peer health visibility'; end if;
 select count(*) into n from public.profiles where id=current_setting('test.athlete')::uuid;
 if n<>0 then raise exception 'FAIL peer profile visibility'; end if;
 begin update public.profiles set role='coach' where id=auth.uid();exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'FAIL role escalation';end if;
 denied:=false;
 begin update public.profiles set team_id=null where id=auth.uid();exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'FAIL direct membership change';end if;
 denied:=false;
 begin update public.profiles set birth_date=current_date-interval '13 years' where id=auth.uid();exception when raise_exception then denied:=true;end;
 if not denied then raise exception 'FAIL minimum registration age';end if;
 denied:=false;
 begin select invite_code into r from public.teams where id=current_setting('test.team')::uuid;exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'FAIL invite disclosure';end if;
 select x into r from public.team_leaderboard(current_setting('test.team')::uuid,current_date,current_date+1) x where x->>'id'=current_setting('test.athlete');
 if (r->'values'->>'SL')::numeric<>60 or (r->'values'->>'GS')::numeric<>60 or (r->'values'->>'totalDirectionChanges')::numeric<>263 then raise exception 'FAIL ski volume: %',r;end if;
 if (r->'values'->>'SG')::numeric<>80 or (r->'values'->>'DH')::numeric<>10 or (r->'values'->>'SX')::numeric<>20 then raise exception 'FAIL speed and ski cross volume: %',r;end if;
 if (r->'values'->>'strengthVolumeKg')::numeric<>650 or (r->'values'->>'strengthSessions')::numeric<>1 then raise exception 'FAIL strength aggregation: %',r;end if;
 if (r->'values'->>'zone23Hours')::numeric<>0.5 then raise exception 'FAIL endurance zones: %',r;end if;
 if r::text like '%never in leaderboard%' or r::text like '%heart_rate_samples%' or r::text like '%avg_hr%' then raise exception 'FAIL leaderboard privacy';end if;
 select count(*) into n from storage.objects where bucket_id='avatars' and name=current_setting('test.athlete')||'/synthetic.png';
 if n<>1 then raise exception 'FAIL teammate avatar read';end if;
 select count(*) into n from storage.objects where bucket_id='avatars' and name=current_setting('test.other_athlete')||'/synthetic.png';
 if n<>0 then raise exception 'FAIL unrelated avatar read';end if;
 denied:=false;
 begin insert into storage.objects(bucket_id,name,owner_id) values('avatars',current_setting('test.athlete')||'/forged.png',auth.uid()::text);exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'FAIL avatar upload spoof';end if;
end $$;
select set_config('request.jwt.claim.sub',current_setting('test.coach'),true);
do $$declare r jsonb; n integer;begin
 r:=public.team_operation('join',payload=>jsonb_build_object('code',current_setting('test.code')));
 if r->>'status'<>'pending' then raise exception 'FAIL coach pending';end if;
 select count(*) into n from public.profiles where id=current_setting('test.athlete')::uuid;
 if n<>0 then raise exception 'FAIL pending coach access';end if;
 begin perform public.team_operation('promote',current_setting('test.team')::uuid,auth.uid());raise exception 'FAIL pending coach self-promotion';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub',current_setting('test.manager'),true);
do $$declare denied boolean:=false; r jsonb; eid uuid;begin
 begin perform public.team_operation('demote',current_setting('test.team')::uuid,auth.uid());exception when raise_exception then denied:=true;end;
 if not denied then raise exception 'FAIL last manager demotion';end if;
 denied:=false;
 begin perform public.team_operation('leave',current_setting('test.team')::uuid);exception when raise_exception then denied:=true;end;
 if not denied then raise exception 'FAIL last manager leaving';end if;
 perform public.team_operation('approve',current_setting('test.team')::uuid,current_setting('test.coach')::uuid);
 perform public.team_operation('promote',current_setting('test.team')::uuid,current_setting('test.coach')::uuid);
 insert into public.calendar_events(team_id,created_by,type,title,date,start_time,end_time,sport_category,technical_details,attendees)
 values(current_setting('test.team')::uuid,auth.uid(),'training','Synthetic event',current_date,'09:00','10:00','ski','{"specialties":["SL"],"tracks":[{"id":"track_1","laps":1,"gates":10}]}',
 jsonb_build_array(jsonb_build_object('id',current_setting('test.athlete'),'name','Synthetic athlete'),jsonb_build_object('id',current_setting('test.peer'),'athleteNotes','private peer response'))) returning id into eid;
 perform set_config('test.event',eid::text,true);
 denied:=false;
 begin insert into public.calendar_events(team_id,created_by,type,title,date,start_time,end_time,attendees)
 values(current_setting('test.team')::uuid,auth.uid(),'training','Invalid attendee',current_date,'09:00','10:00',jsonb_build_array(jsonb_build_object('id',current_setting('test.other_athlete'))));
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'FAIL unauthorized invite';end if;
end $$;
select set_config('request.jwt.claim.sub',current_setting('test.coach'),true);
do $$declare n integer; denied boolean:=false;before_max numeric;begin
 select count(*) into n from public.body_metric_logs where user_id=current_setting('test.athlete')::uuid;
 if n<>1 then raise exception 'FAIL approved coach read';end if;
 update public.body_metric_logs set value=99 where user_id=current_setting('test.athlete')::uuid and type='weight';get diagnostics n=row_count;
 if n<>0 then raise exception 'FAIL coach health update';end if;
 delete from public.body_metric_logs where user_id=current_setting('test.athlete')::uuid and type='weight';get diagnostics n=row_count;
 if n<>0 then raise exception 'FAIL coach health delete';end if;
 begin insert into public.body_metric_logs(user_id,date,type,value) values(current_setting('test.athlete')::uuid,current_date,'sleep_score',100);exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'FAIL coach health insert';end if;
 insert into public.body_metric_logs(user_id,date,type,value) values(current_setting('test.athlete')::uuid,current_date,'sprint_20m',3);
 insert into public.pr_logs(user_id,date,exercise_id,weight) values(current_setting('test.athlete')::uuid,current_date,'squat',80);
 select (one_rep_max->>'squat')::numeric into before_max from public.profiles where id=current_setting('test.athlete')::uuid;
 if before_max<>80 then raise exception 'FAIL PR derived maximum';end if;
 update public.profiles set weight=99 where id=current_setting('test.athlete')::uuid;get diagnostics n=row_count;
 if n<>0 then raise exception 'FAIL coach profile edit';end if;
 update public.training_sessions set details='{}' where user_id=current_setting('test.athlete')::uuid and details->>'source'='health_sync';get diagnostics n=row_count;
 if n<>0 then raise exception 'FAIL coach imported session edit';end if;
 denied:=false;
 begin perform public.team_operation('remove',current_setting('test.team')::uuid,current_setting('test.other_athlete')::uuid);exception when raise_exception then denied:=true;end;
 if not denied then raise exception 'FAIL unrelated member removal';end if;
end $$;
select set_config('request.jwt.claim.sub',current_setting('test.athlete'),true);
do $$declare r jsonb; n integer;denied boolean:=false;begin
 select x into r from public.my_calendar_events(current_setting('test.event')::uuid) x;
 if jsonb_array_length(r->'attendees')<>1 or r::text like '%private peer response%' then raise exception 'FAIL attendee redaction';end if;
 perform public.update_my_event_attendee(current_setting('test.event')::uuid,jsonb_build_object('id',current_setting('test.peer'),'attendanceStatus','present','laps',4,'name','spoofed'));
 select x into r from public.my_calendar_events(current_setting('test.event')::uuid) x;
 if r->'attendees'->0->>'id'<>auth.uid()::text or r->'attendees'->0->>'name'='spoofed' then raise exception 'FAIL own attendee spoof';end if;
 insert into public.training_sessions(user_id,sport_id,date,start_time,end_time,duration,effort,event_id,details)
 values(auth.uid(),'alpine_skiing',current_date,'09:00','10:00','01:00:00',5,current_setting('test.event')::uuid,'{"tracks":[{"specialty":"SL","laps":4,"gates":10}]}');
 begin update public.training_sessions set user_id=current_setting('test.peer')::uuid where user_id=auth.uid();exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'FAIL owner reassignment';end if;
 denied:=false;
 begin insert into public.notifications(user_id,title,message,timestamp) values(current_setting('test.peer')::uuid,'Forged','Forged',now());exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'FAIL forged notification';end if;
 denied:=false;
 begin update public.notifications set message='Forged' where user_id=auth.uid();exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'FAIL notification content mutation';end if;
 update public.notifications set is_read=true where user_id=auth.uid();get diagnostics n=row_count;
 if n<>1 then raise exception 'FAIL recipient notification read state';end if;
 if not private.can_view_avatar(auth.uid()::text) or private.can_view_avatar(current_setting('test.other_athlete')) then raise exception 'FAIL avatar scope';end if;
 insert into storage.objects(bucket_id,name,owner_id) values('avatars',auth.uid()::text||'/own.png',auth.uid()::text);
end $$;
select set_config('request.jwt.claim.sub',current_setting('test.outsider'),true);
do $$declare r jsonb; n integer;denied boolean:=false;begin
 r:=public.team_operation('create',payload=>' {"name":"Synthetic team B"}'::jsonb);
 perform set_config('test.team_b',r->>'team_id',true);
 select count(*) into n from public.body_metric_logs where user_id=current_setting('test.athlete')::uuid;
 if n<>0 then raise exception 'FAIL cross-team health read';end if;
 begin perform public.team_operation('promote',current_setting('test.team')::uuid,current_setting('test.coach')::uuid);exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'FAIL cross-team management';end if;
 denied:=false;
 begin perform public.team_leaderboard(current_setting('test.team')::uuid,current_date,current_date+1);exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'FAIL cross-team leaderboard';end if;
 denied:=false;
 begin insert into public.calendar_events(team_id,created_by,type,title,date,start_time,end_time,technical_details) values(current_setting('test.team_b')::uuid,auth.uid(),'training','Cross-team',current_date,'09:00','10:00',jsonb_build_object('teamIds',jsonb_build_array(current_setting('test.team_b'),current_setting('test.team'))));exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'FAIL cross-team event forgery';end if;
end $$;
select set_config('request.jwt.claim.sub',current_setting('test.manager'),true);
do $$begin
 perform public.team_operation('demote',current_setting('test.team')::uuid,current_setting('test.coach')::uuid);
 perform public.team_operation('remove',current_setting('test.team')::uuid,current_setting('test.coach')::uuid);
end $$;
select set_config('request.jwt.claim.sub',current_setting('test.coach'),true);
do $$declare n integer;denied boolean:=false;begin
 select count(*) into n from public.body_metric_logs where user_id=current_setting('test.athlete')::uuid;
 if n<>0 then raise exception 'FAIL removed coach stale token health access';end if;
 begin perform public.team_operation('approve',current_setting('test.team')::uuid,current_setting('test.peer')::uuid);exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'FAIL revoked manager approval';end if;
end $$;
select set_config('request.jwt.claim.sub',current_setting('test.athlete'),true);
do $$declare n integer;begin
 perform public.team_operation('leave',current_setting('test.team')::uuid);
 update public.training_sessions set effort=6 where user_id=auth.uid() and event_id=current_setting('test.event')::uuid;get diagnostics n=row_count;
 if n<>1 then raise exception 'FAIL own historical session after leaving';end if;
end $$;
reset role;
rollback;
select jsonb_build_object('result','PASS','fixtures','rolled back','tables_unprotected',(select count(*) from pg_tables where schemaname='public' and not rowsecurity)) as security_test_result;
