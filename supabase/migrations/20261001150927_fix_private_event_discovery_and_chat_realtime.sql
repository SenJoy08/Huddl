
create or replace function public.is_discoverable_event(target_event uuid)
returns boolean
language sql
stable
security definer
set search_path to ''
as $function$
  select exists (
    select 1
    from public.events e
    where e.id = target_event
      and e.visibility in ('public', 'private')
      and e.status not in ('completed', 'cancelled')
  );
$function$;

revoke execute on function public.is_discoverable_event(uuid) from public, authenticated;

drop policy if exists events_select_discoverable on public.events;
create policy events_select_discoverable
on public.events
for select
to authenticated
using (
  (
    visibility in ('public', 'private')
    and status not in ('completed', 'cancelled')
  )
  or host_id = auth.uid()
  or is_event_member(id)
  or has_event_join_request(id)
);

drop policy if exists event_sports_select on public.event_sports;
create policy event_sports_select
on public.event_sports
for select
to authenticated
using (
  is_discoverable_event(event_id)
  or is_event_host(event_id)
  or is_event_member(event_id)
  or has_event_join_request(event_id)
);

alter table public.event_messages replica identity full;

do $do$
begin
  if exists (
    select 1
    from pg_catalog.pg_publication
    where pubname = 'supabase_realtime'
  ) then
    if not exists (
      select 1
      from pg_catalog.pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'event_messages'
    ) then
      alter publication supabase_realtime add table public.event_messages;
    end if;
  end if;
end
$do$;
;
