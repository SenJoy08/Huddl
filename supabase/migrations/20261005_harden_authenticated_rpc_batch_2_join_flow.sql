-- Batch 2: make the authenticated join/request RPCs SECURITY INVOKER.

drop policy if exists event_members_insert_self_public on public.event_members;

create policy event_members_insert_self_public
on public.event_members
for insert to authenticated
with check (
  user_id = auth.uid()
  and role = 'member'
  and exists (
    select 1 from public.events e
    where e.id = event_members.event_id
      and e.visibility = 'public'
      and e.status in ('upcoming', 'full')
      and e.host_id <> auth.uid()
  )
);

create or replace function public.join_event(p_event_id uuid)
returns text
language plpgsql
security invoker
set search_path = public, pg_catalog
as $function$
declare
  v_event public.events%rowtype;
  v_member_count integer;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  -- Serialize joins for this event without requiring UPDATE privilege on events.
  perform pg_advisory_xact_lock(hashtextextended(p_event_id::text, 0));

  select * into v_event from public.events where id = p_event_id;
  if not found then raise exception 'Event not found'; end if;
  if v_event.visibility <> 'public' then raise exception 'Private events require a join request'; end if;
  if v_event.status in ('completed', 'cancelled') then raise exception 'Event is no longer joinable'; end if;

  if exists (
    select 1 from public.event_members
    where event_id = p_event_id and user_id = auth.uid()
  ) then return 'already_member'; end if;

  select count(*) into v_member_count
  from public.event_members
  where event_id = p_event_id;

  if v_member_count >= v_event.capacity then return 'full'; end if;

  insert into public.event_members (event_id, user_id, role)
  values (p_event_id, auth.uid(), 'member');

  return 'joined';
end;
$function$;

drop policy if exists event_join_requests_insert_self on public.event_join_requests;

create policy event_join_requests_insert_self
on public.event_join_requests
for insert to authenticated
with check (
  user_id = auth.uid()
  and status = 'pending'
  and exists (
    select 1 from public.events e
    where e.id = event_join_requests.event_id
      and e.visibility = 'private'
      and e.status in ('upcoming', 'full')
      and e.host_id <> auth.uid()
  )
);

create or replace function public.request_event_join(p_event_id uuid)
returns text
language plpgsql
security invoker
set search_path = public, pg_catalog
as $function$
declare
  v_event public.events%rowtype;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;

  select * into v_event from public.events where id = p_event_id;
  if not found then raise exception 'Event not found'; end if;
  if v_event.host_id = auth.uid() then return 'already_member'; end if;
  if v_event.visibility <> 'private' then raise exception 'This event is public; join it directly'; end if;
  if v_event.status in ('completed', 'cancelled') then raise exception 'Event is no longer joinable'; end if;

  if exists (
    select 1 from public.event_members
    where event_id = p_event_id and user_id = auth.uid()
  ) then return 'already_member'; end if;

  if v_event.status = 'full' then return 'full'; end if;

  insert into public.event_join_requests (event_id, user_id, status, decided_at)
  values (p_event_id, auth.uid(), 'pending', null)
  on conflict (event_id, user_id)
  do update set status = 'pending', decided_at = null;

  return 'requested';
end;
$function$;
