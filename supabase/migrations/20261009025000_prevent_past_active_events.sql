-- Reject active events whose start time is in the past, including direct API writes.
-- Completed/cancelled historical events remain valid.
create or replace function public.enforce_future_start_for_active_event()
returns trigger
language plpgsql
set search_path = public, pg_catalog
as $function$
begin
  if new.status in ('upcoming', 'full') and new.starts_at <= now() then
    raise exception 'Active events must start in the future'
      using errcode = '22023';
  end if;
  return new;
end;
$function$;

revoke all on function public.enforce_future_start_for_active_event() from public, anon, authenticated;

drop trigger if exists events_require_future_start on public.events;
create trigger events_require_future_start
before insert or update of starts_at, status on public.events
for each row execute function public.enforce_future_start_for_active_event();
