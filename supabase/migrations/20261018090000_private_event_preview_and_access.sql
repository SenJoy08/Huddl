-- V2 privacy and write-surface guardrails.
-- Apply to the existing Huddl database only after reconciling the historical
-- migration baseline documented in supabase/README.md.

alter table public.events
  add column if not exists host_rated_at timestamptz;

-- PostgREST column grants prevent clients from selecting private location and
-- description fields directly. The RPCs below return them only to event members.
revoke select on table public.events from public, anon, authenticated;
grant select (id, event_type_code, title, starts_at, capacity,
              visibility, status, created_at, updated_at, host_rated_at)
  on table public.events to authenticated;

create or replace function public.get_discoverable_events()
returns table (
  id uuid,
  event_type_code text,
  host_id uuid,
  title text,
  description text,
  starts_at timestamptz,
  location_name text,
  capacity integer,
  visibility text,
  status text,
  host_rated_at timestamptz
)
language sql
stable
security definer
set search_path = public, pg_catalog
as $function$
  select e.id, e.event_type_code,
         case when e.visibility = 'public' or e.host_id = auth.uid()
                   or exists (select 1 from public.event_members em
                              where em.event_id = e.id and em.user_id = auth.uid())
              then e.host_id else null end,
         e.title,
         case when e.visibility = 'public' or e.host_id = auth.uid()
                   or exists (select 1 from public.event_members em
                              where em.event_id = e.id and em.user_id = auth.uid())
              then e.description else null end,
         e.starts_at,
         case when e.visibility = 'public' or e.host_id = auth.uid()
                   or exists (select 1 from public.event_members em
                              where em.event_id = e.id and em.user_id = auth.uid())
              then e.location_name else null end,
         e.capacity, e.visibility, e.status, e.host_rated_at
  from public.events e
  where auth.uid() is not null
    and e.event_type_code in ('sport', 'esports')
    and e.status in ('upcoming', 'full')
  order by e.starts_at asc
  limit 100;
$function$;

create or replace function public.get_my_events()
returns table (
  id uuid,
  event_type_code text,
  host_id uuid,
  title text,
  description text,
  starts_at timestamptz,
  location_name text,
  capacity integer,
  visibility text,
  status text,
  host_rated_at timestamptz
)
language sql
stable
security definer
set search_path = public, pg_catalog
as $function$
  select e.id, e.event_type_code, e.host_id, e.title, e.description,
         e.starts_at, e.location_name, e.capacity, e.visibility, e.status,
         e.host_rated_at
  from public.events e
  where auth.uid() is not null
    and e.event_type_code in ('sport', 'esports')
    and (e.host_id = auth.uid() or exists (
      select 1 from public.event_members em
      where em.event_id = e.id and em.user_id = auth.uid()
    ))
  order by e.starts_at desc;
$function$;

revoke all on function public.get_discoverable_events() from public, anon;
revoke all on function public.get_my_events() from public, anon;
grant execute on function public.get_discoverable_events() to authenticated;
grant execute on function public.get_my_events() to authenticated;

create or replace function public.get_event_rating_context(p_event_id uuid)
returns table (host_id uuid, status text)
language sql
stable
security definer
set search_path = public, pg_catalog
as $function$
  select e.host_id, e.status
  from public.events e
  where e.id = p_event_id
    and e.status = 'completed'
    and auth.uid() is not null
    and exists (select 1 from public.event_members em
                where em.event_id = e.id and em.user_id = auth.uid());
$function$;
revoke all on function public.get_event_rating_context(uuid) from public, anon;
grant execute on function public.get_event_rating_context(uuid) to authenticated;

-- Messages are append-only in the current UI. Prevent a sender from moving an
-- existing message to another event or rewriting its author/body through REST.
revoke update, delete on table public.event_messages from authenticated;

-- Event edits update the event row and its sport-specific row in one database
-- transaction, with host authorization and capacity status recalculation.
create or replace function public.update_sport_event(
  p_event_id uuid, p_title text, p_description text, p_starts_at timestamptz,
  p_location_name text, p_capacity integer, p_visibility text,
  p_sport_id uuid, p_skill_level_code text
)
returns void
language plpgsql
security definer
set search_path = public, pg_catalog
as $function$
declare
  v_event public.events%rowtype;
  v_member_count integer;
begin
  if auth.uid() is null then raise exception 'Not authenticated' using errcode = '28000'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_event_id::text, 0));
  select * into v_event from public.events where id = p_event_id for update;
  if not found then raise exception 'Event not found'; end if;
  if v_event.host_id <> auth.uid() then raise exception 'Only the event host can edit this event' using errcode = '42501'; end if;
  if v_event.event_type_code <> 'sport' then raise exception 'Event type mismatch'; end if;
  if v_event.status not in ('upcoming', 'full') or v_event.starts_at <= now() then raise exception 'This event can no longer be edited'; end if;
  if p_title is null or btrim(p_title) = '' or p_capacity is null or p_capacity < 2 or p_capacity > 1000 or p_starts_at is null or p_starts_at <= now() then raise exception 'Invalid event details'; end if;
  if p_visibility is null or p_visibility not in ('public', 'private') then raise exception 'Invalid event visibility'; end if;
  if not exists (select 1 from public.sports where id = p_sport_id)
     or not exists (select 1 from public.skill_levels where code = p_skill_level_code) then raise exception 'Invalid sport or skill level'; end if;

  select count(*) into v_member_count from public.event_members where event_id = p_event_id;
  if p_capacity < v_member_count then raise exception 'Capacity cannot be lower than the current player count'; end if;
  update public.events set title = btrim(p_title), description = nullif(btrim(p_description), ''),
    starts_at = p_starts_at, location_name = nullif(btrim(p_location_name), ''),
    capacity = p_capacity, visibility = p_visibility,
    status = case when v_member_count >= p_capacity then 'full' else 'upcoming' end,
    updated_at = now()
  where id = p_event_id;
  insert into public.event_sports(event_id, sport_id, skill_level_code)
  values (p_event_id, p_sport_id, p_skill_level_code)
  on conflict (event_id) do update set sport_id = excluded.sport_id, skill_level_code = excluded.skill_level_code;
end;
$function$;

create or replace function public.update_esports_event(
  p_event_id uuid, p_title text, p_description text, p_starts_at timestamptz,
  p_location_name text, p_capacity integer, p_visibility text,
  p_game_id uuid, p_platform text, p_game_mode text, p_skill_level_code text
)
returns void
language plpgsql
security definer
set search_path = public, pg_catalog
as $function$
declare
  v_event public.events%rowtype;
  v_member_count integer;
begin
  if auth.uid() is null then raise exception 'Not authenticated' using errcode = '28000'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_event_id::text, 0));
  select * into v_event from public.events where id = p_event_id for update;
  if not found then raise exception 'Event not found'; end if;
  if v_event.host_id <> auth.uid() then raise exception 'Only the event host can edit this event' using errcode = '42501'; end if;
  if v_event.event_type_code <> 'esports' then raise exception 'Event type mismatch'; end if;
  if v_event.status not in ('upcoming', 'full') or v_event.starts_at <= now() then raise exception 'This event can no longer be edited'; end if;
  if p_title is null or btrim(p_title) = '' or p_capacity is null or p_capacity < 2 or p_capacity > 1000 or p_starts_at is null or p_starts_at <= now() then raise exception 'Invalid event details'; end if;
  if p_visibility is null or p_visibility not in ('public', 'private') then raise exception 'Invalid event visibility'; end if;
  if not exists (select 1 from public.esports_games where id = p_game_id and enabled)
     or not exists (select 1 from public.skill_levels where code = p_skill_level_code) then raise exception 'Invalid game or skill level'; end if;

  select count(*) into v_member_count from public.event_members where event_id = p_event_id;
  if p_capacity < v_member_count then raise exception 'Capacity cannot be lower than the current player count'; end if;
  update public.events set title = btrim(p_title), description = nullif(btrim(p_description), ''),
    starts_at = p_starts_at, location_name = nullif(btrim(p_location_name), ''),
    capacity = p_capacity, visibility = p_visibility,
    status = case when v_member_count >= p_capacity then 'full' else 'upcoming' end,
    updated_at = now()
  where id = p_event_id;
  insert into public.event_esports(event_id, game_id, platform, game_mode, skill_level_code)
  values (p_event_id, p_game_id, nullif(btrim(p_platform), ''), nullif(btrim(p_game_mode), ''), p_skill_level_code)
  on conflict (event_id) do update set game_id = excluded.game_id, platform = excluded.platform,
    game_mode = excluded.game_mode, skill_level_code = excluded.skill_level_code;
end;
$function$;

revoke all on function public.update_sport_event(uuid, text, text, timestamptz, text, integer, text, uuid, text) from public, anon;
revoke all on function public.update_esports_event(uuid, text, text, timestamptz, text, integer, text, uuid, text, text, text) from public, anon;
grant execute on function public.update_sport_event(uuid, text, text, timestamptz, text, integer, text, uuid, text) to authenticated;
grant execute on function public.update_esports_event(uuid, text, text, timestamptz, text, integer, text, uuid, text, text, text) to authenticated;

-- Friend writes go through checked transactions so accepting a request and
-- creating the canonical friendship cannot drift apart.
revoke insert, update, delete on table public.friend_requests from authenticated;
revoke insert, delete on table public.friendships from authenticated;

create or replace function public.send_friend_request(p_receiver_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_catalog
as $function$
declare
  v_sender uuid := auth.uid();
  v_status text;
begin
  if v_sender is null then raise exception 'Not authenticated' using errcode = '28000'; end if;
  if p_receiver_id is null or p_receiver_id = v_sender then raise exception 'Choose another player'; end if;
  if not exists (select 1 from public.profiles where id = p_receiver_id) then raise exception 'Player not found'; end if;
  if exists (select 1 from public.friendships where user_a = least(v_sender, p_receiver_id) and user_b = greatest(v_sender, p_receiver_id)) then return 'already_friend'; end if;
  if exists (select 1 from public.friend_requests where sender_id = p_receiver_id and receiver_id = v_sender and status = 'pending') then return 'incoming_pending'; end if;

  select status into v_status from public.friend_requests
  where sender_id = v_sender and receiver_id = p_receiver_id;
  if found and v_status = 'pending' then return 'already_pending'; end if;
  if found and v_status = 'accepted' then
    insert into public.friendships(user_a, user_b)
    values (least(v_sender, p_receiver_id), greatest(v_sender, p_receiver_id))
    on conflict do nothing;
    return 'already_friend';
  end if;

  insert into public.friend_requests(sender_id, receiver_id, status, decided_at)
  values (v_sender, p_receiver_id, 'pending', null)
  on conflict (sender_id, receiver_id) do update
    set status = case when public.friend_requests.status in ('declined', 'cancelled') then 'pending' else public.friend_requests.status end,
        decided_at = case when public.friend_requests.status in ('declined', 'cancelled') then null else public.friend_requests.decided_at end
  returning status into v_status;
  return case when v_status = 'pending' then 'sent' else v_status end;
end;
$function$;

create or replace function public.respond_friend_request(p_request_id uuid, p_accept boolean)
returns text
language plpgsql
security definer
set search_path = public, pg_catalog
as $function$
declare
  v_request public.friend_requests%rowtype;
  v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'Not authenticated' using errcode = '28000'; end if;
  select * into v_request from public.friend_requests where id = p_request_id for update;
  if not found then raise exception 'Friend request not found'; end if;
  if v_request.receiver_id <> v_user then raise exception 'Only the recipient can decide this request' using errcode = '42501'; end if;
  if v_request.status = 'accepted' then
    insert into public.friendships(user_a, user_b)
    values (least(v_request.sender_id, v_request.receiver_id), greatest(v_request.sender_id, v_request.receiver_id))
    on conflict do nothing;
    return 'accepted';
  end if;
  if v_request.status <> 'pending' then return v_request.status; end if;

  if p_accept then
    insert into public.friendships(user_a, user_b)
    values (least(v_request.sender_id, v_request.receiver_id), greatest(v_request.sender_id, v_request.receiver_id))
    on conflict do nothing;
    update public.friend_requests set status = 'accepted', decided_at = now() where id = p_request_id;
    return 'accepted';
  end if;
  update public.friend_requests set status = 'declined', decided_at = now() where id = p_request_id;
  return 'declined';
end;
$function$;

create or replace function public.remove_friend(p_friend_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_catalog
as $function$
declare
  v_user uuid := auth.uid();
  v_deleted integer;
begin
  if v_user is null then raise exception 'Not authenticated' using errcode = '28000'; end if;
  if p_friend_id is null or p_friend_id = v_user then raise exception 'Choose another player'; end if;
  delete from public.friendships
  where user_a = least(v_user, p_friend_id) and user_b = greatest(v_user, p_friend_id);
  get diagnostics v_deleted = row_count;
  if v_deleted = 0 then return 'not_friends'; end if;
  update public.friend_requests set status = 'cancelled', decided_at = now()
  where status = 'accepted' and ((sender_id = v_user and receiver_id = p_friend_id) or (sender_id = p_friend_id and receiver_id = v_user));
  return 'removed';
end;
$function$;

revoke all on function public.send_friend_request(uuid) from public, anon;
revoke all on function public.respond_friend_request(uuid, boolean) from public, anon;
revoke all on function public.remove_friend(uuid) from public, anon;
grant execute on function public.send_friend_request(uuid) to authenticated;
grant execute on function public.respond_friend_request(uuid, boolean) to authenticated;
grant execute on function public.remove_friend(uuid) to authenticated;

