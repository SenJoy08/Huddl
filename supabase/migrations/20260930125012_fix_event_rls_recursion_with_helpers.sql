create or replace function public.is_public_event(target_event uuid)
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select exists (
    select 1
    from public.events e
    where e.id = target_event
      and e.visibility = 'public'
  );
$$;

create or replace function public.has_event_join_request(target_event uuid)
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select exists (
    select 1
    from public.event_join_requests r
    where r.event_id = target_event
      and r.user_id = auth.uid()
  );
$$;

revoke execute on function public.is_public_event(uuid) from public, anon, authenticated;
revoke execute on function public.has_event_join_request(uuid) from public, anon, authenticated;

drop policy if exists events_select_discoverable on public.events;
create policy events_select_discoverable
on public.events
for select
to authenticated
using (
  visibility = 'public'
  or host_id = auth.uid()
  or public.is_event_member(id)
  or public.has_event_join_request(id)
);

drop policy if exists event_members_select on public.event_members;
create policy event_members_select
on public.event_members
for select
to authenticated
using (
  user_id = auth.uid()
  or public.is_event_host(event_id)
  or public.is_public_event(event_id)
);

drop policy if exists event_members_insert_host on public.event_members;
create policy event_members_insert_host
on public.event_members
for insert
to authenticated
with check (
  public.is_event_host(event_id)
);

drop policy if exists event_members_update_host on public.event_members;
create policy event_members_update_host
on public.event_members
for update
to authenticated
using (public.is_event_host(event_id))
with check (public.is_event_host(event_id));

drop policy if exists event_members_delete_self_or_host on public.event_members;
create policy event_members_delete_self_or_host
on public.event_members
for delete
to authenticated
using (
  user_id = auth.uid()
  or public.is_event_host(event_id)
);

drop policy if exists event_join_requests_select on public.event_join_requests;
create policy event_join_requests_select
on public.event_join_requests
for select
to authenticated
using (
  user_id = auth.uid()
  or public.is_event_host(event_id)
);

drop policy if exists event_join_requests_update_self_or_host on public.event_join_requests;
create policy event_join_requests_update_self_or_host
on public.event_join_requests
for update
to authenticated
using (
  user_id = auth.uid()
  or public.is_event_host(event_id)
)
with check (
  user_id = auth.uid()
  or public.is_event_host(event_id)
);

drop policy if exists event_sports_select on public.event_sports;
create policy event_sports_select
on public.event_sports
for select
to authenticated
using (
  public.is_public_event(event_id)
  or public.is_event_host(event_id)
  or public.is_event_member(event_id)
);

drop policy if exists event_sports_write on public.event_sports;
create policy event_sports_write
on public.event_sports
for all
to authenticated
using (public.is_event_host(event_id))
with check (public.is_event_host(event_id));

grant execute on function public.is_public_event(uuid) to authenticated;
grant execute on function public.has_event_join_request(uuid) to authenticated;
;
