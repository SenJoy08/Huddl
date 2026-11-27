insert into public.esports_games (slug, name, platform, enabled)
values
  ('valorant', 'Valorant', 'PC', true),
  ('counter-strike-2', 'Counter-Strike 2', 'PC', true),
  ('rocket-league', 'Rocket League', 'PC & Console', true),
  ('fortnite', 'Fortnite', 'PC & Console', true),
  ('ea-sports-fc', 'EA Sports FC', 'PC & Console', true),
  ('bgmi', 'BGMI', 'Mobile', true),
  ('call-of-duty-mobile', 'Call of Duty: Mobile', 'Mobile', true),
  ('overwatch-2', 'Overwatch 2', 'PC & Console', true),
  ('league-of-legends', 'League of Legends', 'PC', true),
  ('dota-2', 'Dota 2', 'PC', true)
on conflict (slug) do update
set name = excluded.name, platform = excluded.platform, enabled = true;

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
  p_team_size integer
)
returns uuid
language plpgsql
security invoker
set search_path to 'public', 'pg_catalog'
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
  if p_team_size is null or p_team_size < 1 or p_team_size > 100 then raise exception 'Team size must be between 1 and 100'; end if;
  if not exists (select 1 from public.esports_games where id = p_game_id and enabled) then raise exception 'Invalid esports game'; end if;
  if not exists (select 1 from public.profiles where id = auth.uid()) then raise exception 'Complete your profile before creating an event'; end if;

  insert into public.events (
    event_type_code, host_id, title, description, starts_at,
    location_name, capacity, visibility, status
  ) values (
    'esports', auth.uid(), btrim(p_title),
    nullif(btrim(coalesce(p_description, '')), ''),
    p_starts_at, btrim(p_location_name), p_capacity,
    p_visibility, 'upcoming'
  ) returning id into v_event_id;

  insert into public.event_esports (event_id, game_id, platform, game_mode, team_size)
  values (v_event_id, p_game_id, nullif(btrim(coalesce(p_platform, '')), ''), nullif(btrim(coalesce(p_game_mode, '')), ''), p_team_size);

  return v_event_id;
end;
$$;

revoke execute on function public.create_esports_event(text,text,timestamptz,text,integer,text,uuid,text,text,integer) from public;
grant execute on function public.create_esports_event(text,text,timestamptz,text,integer,text,uuid,text,text,integer) to authenticated;

drop policy if exists event_esports_select on public.event_esports;
create policy event_esports_select
on public.event_esports
for select
to authenticated
using (
  exists (
    select 1
    from public.events e
    where e.id = event_esports.event_id
      and (
        e.visibility = 'public'
        or e.host_id = auth.uid()
        or exists (select 1 from public.event_members em where em.event_id = e.id and em.user_id = auth.uid())
        or exists (select 1 from public.event_join_requests r where r.event_id = e.id and r.user_id = auth.uid() and r.status = 'pending')
      )
  )
);;
