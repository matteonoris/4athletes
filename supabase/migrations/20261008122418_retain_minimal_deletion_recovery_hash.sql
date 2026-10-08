-- A non-reversible account UUID hash permits pre-restore checks without
-- retaining names, email, health data or the original deleted user UUID.
-- It stays private, expires with the receipt 30 days after completion, and
-- is not exposed by the public receipt-status RPC.
alter table private.account_deletions add column subject_hash bytea;
update private.account_deletions set subject_hash=extensions.digest(user_id::text,'sha256') where user_id is not null;
create function private.hash_deletion_subject() returns trigger
language plpgsql set search_path='' as $$
begin
 new.subject_hash:=extensions.digest(new.user_id::text,'sha256');
 return new;
end $$;
revoke all on function private.hash_deletion_subject() from public,anon,authenticated;
create trigger hash_deletion_subject before insert on private.account_deletions
 for each row execute function private.hash_deletion_subject();
