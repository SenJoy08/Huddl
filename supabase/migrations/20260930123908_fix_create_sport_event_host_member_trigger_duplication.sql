CREATE OR REPLACE FUNCTION public.create_sport_event(p_title text, p_description text, p_starts_at timestamp with time zone, p_location_name text, p_capacity integer, p_visibility text, p_sport_id uuid, p_skill_level_code text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'public', 'pg_catalog'
AS $$
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

  -- The events AFTER INSERT trigger already adds the host to event_members.
  return v_event_id;
end;
$$;;
