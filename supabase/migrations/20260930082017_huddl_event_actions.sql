
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
security definer
set search_path = public, pg_catalog
as $$
declare
  v_event_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if p_title is null or btrim(p_title) = '' then
    raise exception 'Event title is required';
  end if;

  if p_starts_at is null then
    raise exception 'Event start time is required';
  end if;

  if p_location_name is null or btrim(p_location_name) = '' then
    raise exception 'Event location is required';
  end if;

  if p_capacity < 2 or p_capacity > 1000 then
    raise exception 'Capacity must be between 2 and 1000';
  end if;

  if p_visibility not in ('public', 'private') then
    raise exception 'Invalid visibility';
  end if;

  if not exists (select 1 from public.sports where id = p_sport_id and enabled) then
    raise exception 'Invalid sport';
  end if;

  if not exists (select 1 from public.skill_levels where code = p_skill_level_code) then
    raise exception 'Invalid skill level';
  end if;

  if not exists (select 1 from public.profiles where id = auth.uid()) then
    raise exception 'Complete your profile before creating an event';
  end if;

  insert into public.events (
    event_type_code,
    host_id,
    title,
    description,
    starts_at,
    location_name,
    capacity,
    visibility,
    status
  )
  values (
    'sport',
    auth.uid(),
    btrim(p_title),
    nullif(btrim(coalesce(p_description, '')), ''),
    p_starts_at,
    btrim(p_location_name),
    p_capacity,
    p_visibility,
    case when p_capacity = 1 then 'full' else 'upcoming' end
  )
  returning id into v_event_id;

  insert into public.event_sports (
    event_id,
    sport_id,
    skill_level_code
  )
  values (
    v_event_id,
    p_sport_id,
    p_skill_level_code
  );

  insert into public.event_members (
    event_id,
    user_id,
    role
  )
  values (
    v_event_id,
    auth.uid(),
    'host'
  );

  return v_event_id;
end;
$$;

create or replace function public.join_event(p_event_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_event public.events%rowtype;
  v_member_count integer;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select *
  into v_event
  from public.events
  where id = p_event_id
  for update;

  if not found then
    raise exception 'Event not found';
  end if;

  if v_event.visibility <> 'public' then
    raise exception 'Private events require a join request';
  end if;

  if v_event.status in ('completed', 'cancelled') then
    raise exception 'Event is no longer joinable';
  end if;

  if exists (
    select 1
    from public.event_members
    where event_id = p_event_id
      and user_id = auth.uid()
  ) then
    return 'already_member';
  end if;

  select count(*)
  into v_member_count
  from public.event_members
  where event_id = p_event_id;

  if v_member_count >= v_event.capacity then
    update public.events
    set status = 'full', updated_at = now()
    where id = p_event_id;
    return 'full';
  end if;

  insert into public.event_members (event_id, user_id, role)
  values (p_event_id, auth.uid(), 'member');

  v_member_count := v_member_count + 1;

  update public.events
  set
    status = case when v_member_count >= capacity then 'full' else 'upcoming' end,
    updated_at = now()
  where id = p_event_id;

  return 'joined';
end;
$$;

create or replace function public.leave_event(p_event_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_host_id uuid;
  v_deleted integer;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select host_id
  into v_host_id
  from public.events
  where id = p_event_id;

  if not found then
    raise exception 'Event not found';
  end if;

  if v_host_id = auth.uid() then
    raise exception 'The host cannot leave their own event';
  end if;

  delete from public.event_members
  where event_id = p_event_id
    and user_id = auth.uid();

  get diagnostics v_deleted = row_count;

  if v_deleted = 0 then
    return 'not_member';
  end if;

  update public.events
  set
    status = case when status = 'full' then 'upcoming' else status end,
    updated_at = now()
  where id = p_event_id;

  return 'left';
end;
$$;

revoke all on function public.create_sport_event(text,text,timestamptz,text,integer,text,uuid,text) from public, anon;
revoke all on function public.join_event(uuid) from public, anon;
revoke all on function public.leave_event(uuid) from public, anon;

grant execute on function public.create_sport_event(text,text,timestamptz,text,integer,text,uuid,text) to authenticated;
grant execute on function public.join_event(uuid) to authenticated;
grant execute on function public.leave_event(uuid) to authenticated;
;
