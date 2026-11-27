
-- Fix esports event metadata hydration under event column-level privileges.
-- Avoid querying public.events directly from the event_esports RLS policy.

grant usage on schema private to authenticated;

grant execute on function private.is_discoverable_event(uuid)
  to authenticated;

grant execute on function private.is_event_host(uuid)
  to authenticated;

grant execute on function private.is_event_member(uuid)
  to authenticated;

grant execute on function private.has_event_join_request(uuid)
  to authenticated;

drop policy if exists event_esports_select
  on public.event_esports;

create policy event_esports_select
on public.event_esports
for select
to authenticated
using (
  private.is_discoverable_event(event_id)
  or private.is_event_host(event_id)
  or private.is_event_member(event_id)
  or private.has_event_join_request(event_id)
);
