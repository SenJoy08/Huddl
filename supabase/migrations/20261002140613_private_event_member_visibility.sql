
drop policy if exists event_members_select on public.event_members;

create policy event_members_select
on public.event_members
for select
to authenticated
using (
  user_id = auth.uid()
  or is_event_host(event_id)
  or is_event_member(event_id)
  or is_public_event(event_id)
  or user_id = (
    select e.host_id
    from public.events e
    where e.id = event_members.event_id
  )
);
;
