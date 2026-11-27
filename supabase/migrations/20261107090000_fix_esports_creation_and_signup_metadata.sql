-- Forward-only repair for the deployed esports RPC contract and signup metadata.

create or replace function public.create_esports_event(
  p_title text,
  p_description text,
  p_starts_at timestamptz,
  p_location_name text,
  p_capacity integer,
  p_visibility text,
  p_game_id uuid,
  p_platform text,
  p_game_mode text,
  p_skill_level_code text,
  p_team_size integer default null
)
returns uuid
language plpgsql
security invoker
set search_path = public, pg_catalog
as $function$
declare
  v_event_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;
  if p_title is null or btrim(p_title) = '' then
    raise exception 'Event title is required';
  end if;
  if p_starts_at is null or p_starts_at <= now() then
    raise exception 'Choose a start time in the future';
  end if;
  if p_location_name is null or btrim(p_location_name) = '' then
    raise exception 'Event location is required';
  end if;
  if p_capacity is null or p_capacity < 2 or p_capacity > 1000 then
    raise exception 'Capacity must be between 2 and 1000';
  end if;
  if p_visibility is null or p_visibility not in ('public', 'private') then
    raise exception 'Invalid visibility';
  end if;
  if p_team_size is not null and (p_team_size < 1 or p_team_size > 100) then
    raise exception 'Team size must be between 1 and 100';
  end if;
  if not exists (
    select 1 from public.esports_games
    where id = p_game_id and enabled
  ) then
    raise exception 'Selected esports game is unavailable';
  end if;
  if not exists (select 1 from public.skill_levels where code = p_skill_level_code) then
    raise exception 'Selected skill level is unavailable';
  end if;
  if not exists (select 1 from public.profiles where id = auth.uid()) then
    raise exception 'Complete your profile before creating an event';
  end if;

  -- The events AFTER INSERT trigger adds the host membership. Both inserts
  -- remain part of this RPC transaction and roll back together on any failure.
  insert into public.events (
    event_type_code, host_id, title, description, starts_at,
    location_name, capacity, visibility, status
  ) values (
    'esports', auth.uid(), btrim(p_title),
    nullif(btrim(coalesce(p_description, '')), ''),
    p_starts_at, btrim(p_location_name), p_capacity,
    p_visibility, 'upcoming'
  ) returning id into v_event_id;

  insert into public.event_esports (
    event_id, game_id, platform, game_mode, team_size, skill_level_code
  ) values (
    v_event_id, p_game_id,
    nullif(btrim(coalesce(p_platform, '')), ''),
    nullif(btrim(coalesce(p_game_mode, '')), ''),
    p_team_size, p_skill_level_code
  );

  return v_event_id;
end;
$function$;

revoke all on function public.create_esports_event(
  text, text, timestamptz, text, integer, text, uuid, text, text, text, integer
) from public, anon;
grant execute on function public.create_esports_event(
  text, text, timestamptz, text, integer, text, uuid, text, text, text, integer
) to authenticated;

-- The prior team-size-only overload cannot populate the NOT NULL skill field.
-- Keep the function object for migration compatibility, but close its API.
revoke execute on function public.create_esports_event(
  text, text, timestamptz, text, integer, text, uuid, text, text, integer
) from public, anon, authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  display_name_value text;
begin
  display_name_value := coalesce(
    nullif(trim(new.raw_user_meta_data->>'display_name'), ''),
    nullif(trim(new.raw_user_meta_data->>'name'), ''),
    split_part(coalesce(new.email, 'huddl-user'), '@', 1)
  );
  insert into public.profiles (id, display_name)
  values (new.id, display_name_value)
  on conflict (id) do nothing;
  insert into public.notification_preferences (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$function$;
