do $$
declare
  constraint_record record;
begin
  if to_regclass('public.body_metric_logs') is null then
    return;
  end if;

  for constraint_record in
    select conname
    from pg_constraint
    where conrelid = to_regclass('public.body_metric_logs')
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%type%'
  loop
    execute format(
      'alter table public.body_metric_logs drop constraint %I',
      constraint_record.conname
    );
  end loop;
end $$;
