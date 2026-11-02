
create policy friendships_insert_participant
on public.friendships
for insert
to authenticated
with check (
  (user_a = auth.uid() or user_b = auth.uid())
  and exists (
    select 1
    from public.friend_requests fr
    where fr.status = 'accepted'
      and (
        (fr.sender_id = friendships.user_a and fr.receiver_id = friendships.user_b)
        or
        (fr.sender_id = friendships.user_b and fr.receiver_id = friendships.user_a)
      )
  )
);

create or replace function public.create_sport_event(
  p_title text,
  p_description text,
  p_starts_at timestamptz,
  p_location_name text,
  p_capacity integer,
  p_visibility text,
  p_sport_id uuid,
  p_skill_level_code text
)
returns uuid
language plpgsql
security invoker
set search_path = public, pg_catalog
as $$
declare
  v_event_id uuid;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  if p_title is null or btrim(p_title) = '' then raise exception 'Event title is required'; end if;
  if p_starts_at is null then raise exception 'Event start time is required'; end if;
  if p_location_name is null or btrim(p_location_name) = '' then raise exception 'Event location is required'; end if;
  if p_capacity < 2 or p_capacity > 1000 then raise exception 'Capacity must be between 2 and 1000'; end if;
  if p_visibility not in ('public', 'private') then raise exception 'Invalid visibility'; end if;
  if not exists (select 1 from public.sports where id = p_sport_id and enabled) then raise exception 'Invalid sport'; end if;
  if not exists (select 1 from public.skill_levels where code = p_skill_level_code) then raise exception 'Invalid skill level'; end if;
  if not exists (select 1 from public.profiles where id = auth.uid()) then raise exception 'Complete your profile before creating an event'; end if;

  insert into public.events (
    event_type_code, host_id, title, description, starts_at,
    location_name, capacity, visibility, status
  )
  values (
    'sport', auth.uid(), btrim(p_title),
    nullif(btrim(coalesce(p_description, '')), ''),
    p_starts_at, btrim(p_location_name), p_capacity,
    p_visibility, 'upcoming'
  )
  returning id into v_event_id;

  insert into public.event_sports (event_id, sport_id, skill_level_code)
  values (v_event_id, p_sport_id, p_skill_level_code);

  insert into public.event_members (event_id, user_id, role)
  values (v_event_id, auth.uid(), 'host');

  return v_event_id;
end;
$$;

create or replace function public.join_event(p_event_id uuid)
returns text
language plpgsql
security invoker
set search_path = public, pg_catalog
as $$
declare
  v_event public.events%rowtype;
  v_member_count integer;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;

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
$$;

create or replace function public.leave_event(p_event_id uuid)
returns text
language plpgsql
security invoker
set search_path = public, pg_catalog
as $$
declare
  v_host_id uuid;
  v_deleted integer;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;

  select host_id into v_host_id from public.events where id = p_event_id;
  if not found then raise exception 'Event not found'; end if;
  if v_host_id = auth.uid() then raise exception 'The host cannot leave their own event'; end if;

  delete from public.event_members
  where event_id = p_event_id and user_id = auth.uid();

  get diagnostics v_deleted = row_count;
  if v_deleted = 0 then return 'not_member'; end if;
  return 'left';
end;
$$;

create or replace function public.decide_event_join_request(
  p_request_id uuid,
  p_accept boolean
)
returns text
language plpgsql
security invoker
set search_path = public, pg_catalog
as $$
declare
  v_request public.event_join_requests%rowtype;
  v_event public.events%rowtype;
  v_member_count integer;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;

  select * into v_request
  from public.event_join_requests
  where id = p_request_id
  for update;

  if not found then raise exception 'Join request not found'; end if;

  select * into v_event
  from public.events
  where id = v_request.event_id
  for update;

  if not found then raise exception 'Event not found'; end if;
  if v_event.host_id <> auth.uid() then raise exception 'Only the event host can decide this request'; end if;
  if v_request.status <> 'pending' then return v_request.status; end if;

  if not p_accept then
    update public.event_join_requests
    set status = 'declined', decided_at = now()
    where id = p_request_id;
    return 'declined';
  end if;

  select count(*) into v_member_count
  from public.event_members
  where event_id = v_event.id;

  if v_member_count >= v_event.capacity then
    update public.events set status = 'full', updated_at = now()
    where id = v_event.id;
    raise exception 'Event is full';
  end if;

  insert into public.event_join_requests(id, event_id, user_id, status, decided_at)
  values (v_request.id, v_request.event_id, v_request.user_id, 'accepted', now())
  on conflict (id) do update
  set status = 'accepted', decided_at = now();

  insert into public.event_members (event_id, user_id, role)
  values (v_event.id, v_request.user_id, 'member')
  on conflict (event_id, user_id) do nothing;

  v_member_count := v_member_count + 1;

  update public.events
  set status = case when v_member_count >= capacity then 'full' else 'upcoming' end,
      updated_at = now()
  where id = v_event.id;

  return 'accepted';
end;
$$;

create or replace function public.send_friend_request(p_receiver_id uuid)
returns text
language plpgsql
security invoker
set search_path = public, pg_catalog
as $$
declare
  v_existing_status text;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  if p_receiver_id is null or p_receiver_id = auth.uid() then raise exception 'Invalid friend request target'; end if;
  if not exists (select 1 from public.profiles where id = p_receiver_id) then raise exception 'User not found'; end if;

  if exists (
    select 1 from public.friendships
    where user_a = least(auth.uid(), p_receiver_id) and user_b = greatest(auth.uid(), p_receiver_id)
  ) then return 'already_friend'; end if;

  select status into v_existing_status
  from public.friend_requests
  where sender_id = auth.uid() and receiver_id = p_receiver_id
  order by created_at desc limit 1;

  if v_existing_status = 'pending' then return 'already_pending'; end if;

  if exists (
    select 1 from public.friend_requests
    where sender_id = p_receiver_id and receiver_id = auth.uid() and status = 'pending'
  ) then return 'incoming_pending'; end if;

  insert into public.friend_requests (sender_id, receiver_id, status)
  values (auth.uid(), p_receiver_id, 'pending');

  return 'sent';
end;
$$;

create or replace function public.respond_friend_request(
  p_request_id uuid,
  p_accept boolean
)
returns text
language plpgsql
security invoker
set search_path = public, pg_catalog
as $$
declare
  v_request public.friend_requests%rowtype;
  v_user_a uuid;
  v_user_b uuid;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;

  select * into v_request
  from public.friend_requests
  where id = p_request_id
  for update;

  if not found then raise exception 'Friend request not found'; end if;
  if v_request.receiver_id <> auth.uid() then raise exception 'Only the recipient can decide this request'; end if;
  if v_request.status <> 'pending' then return v_request.status; end if;

  if not p_accept then
    update public.friend_requests
    set status = 'declined', decided_at = now()
    where id = p_request_id;
    return 'declined';
  end if;

  v_user_a := least(v_request.sender_id, v_request.receiver_id);
  v_user_b := greatest(v_request.sender_id, v_request.receiver_id);

  update public.friend_requests
  set status = 'accepted', decided_at = now()
  where id = p_request_id;

  insert into public.friendships (user_a, user_b)
  values (v_user_a, v_user_b)
  on conflict do nothing;

  return 'accepted';
end;
$$;

create or replace function public.remove_friend(p_friend_id uuid)
returns text
language plpgsql
security invoker
set search_path = public, pg_catalog
as $$
declare
  v_deleted integer;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  if p_friend_id is null or p_friend_id = auth.uid() then raise exception 'Invalid friend'; end if;

  delete from public.friendships
  where user_a = least(auth.uid(), p_friend_id)
    and user_b = greatest(auth.uid(), p_friend_id);

  get diagnostics v_deleted = row_count;
  if v_deleted = 0 then return 'not_friends'; end if;
  return 'removed';
end;
$$;
;
