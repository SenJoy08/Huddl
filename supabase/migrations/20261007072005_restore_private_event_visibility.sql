drop policy if exists events_select_discoverable on public.events;

create policy events_select_discoverable
on public.events
for select
to authenticated
using (
  (
    visibility = 'public'
    and status <> all (array['completed','cancelled'])
  )
  or host_id = (select auth.uid())
  or private.is_event_member(id)
  or private.has_event_join_request(id)
);;
