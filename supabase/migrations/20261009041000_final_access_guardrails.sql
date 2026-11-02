-- Final access guardrails discovered during the production code audit.
-- Apply to the existing Huddl Supabase project after reconciling the historical
-- RPC migrations (see supabase/README.md). This is a forward-only migration.

alter table public.events
  add column if not exists host_rated_at timestamptz;

-- Event editing from the client only needs these columns. Lifecycle transitions
-- and the rating-complete marker must go through host-checked RPCs below.
revoke update on table public.events from authenticated;
grant update (title, description, starts_at, location_name, capacity, visibility)
  on table public.events to authenticated;

-- Make lifecycle transitions atomic and independently authorize the event host.
create or replace function public.complete_event(p_event_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_catalog
as $function$
declare
  v_event public.events%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  select * into v_event
  from public.events
  where id = p_event_id
  for update;

  if not found then raise exception 'Event not found'; end if;
  if v_event.host_id <> auth.uid() then
    raise exception 'Only the event host can complete this event' using errcode = '42501';
  end if;
  if v_event.status = 'completed' then
    update public.event_members
    set showed_up = true
    where event_id = p_event_id and user_id = auth.uid() and role = 'host';
    return 'completed';
  end if;
  if v_event.status not in ('upcoming', 'full') then
    raise exception 'This event cannot be completed';
  end if;
  if v_event.starts_at > now() then
    raise exception 'An event cannot be completed before its start time';
  end if;

  update public.events
  set status = 'completed', updated_at = now()
  where id = p_event_id;

  -- Completing the event is the host's explicit post-game action, so record
  -- the host as present; hosts cannot rate themselves through the player list.
  update public.event_members
  set showed_up = true
  where event_id = p_event_id and user_id = auth.uid() and role = 'host';

  return 'completed';
end;
$function$;

create or replace function public.cancel_event(p_event_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_catalog
as $function$
declare
  v_event public.events%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  select * into v_event
  from public.events
  where id = p_event_id
  for update;

  if not found then raise exception 'Event not found'; end if;
  if v_event.host_id <> auth.uid() then
    raise exception 'Only the event host can cancel this event' using errcode = '42501';
  end if;
  if v_event.status not in ('upcoming', 'full') then
    if v_event.status = 'cancelled' then return 'cancelled'; end if;
    raise exception 'This event can no longer be cancelled';
  end if;

  update public.events
  set status = 'cancelled', updated_at = now()
  where id = p_event_id;

  update public.event_join_requests
  set status = 'declined', decided_at = now()
  where event_id = p_event_id and status = 'pending';

  return 'cancelled';
end;
$function$;

create or replace function public.mark_host_ratings_complete(p_event_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public, pg_catalog
as $function$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  update public.events
  set host_rated_at = coalesce(host_rated_at, now()), updated_at = now()
  where id = p_event_id
    and host_id = auth.uid()
    and status = 'completed';

  if not found then
    raise exception 'Only the host of a completed event can finish ratings' using errcode = '42501';
  end if;

  return true;
end;
$function$;


-- Public joins must still work after direct membership INSERT is revoked. Keep
-- capacity checks and membership creation in one authorized transaction.
create or replace function public.join_event(p_event_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_catalog
as $function$
declare
  v_event public.events%rowtype;
  v_member_count integer;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_event_id::text, 0));
  select * into v_event
  from public.events
  where id = p_event_id
  for update;
  if not found then raise exception 'Event not found'; end if;
  if v_event.visibility <> 'public' then
    raise exception 'Private events require a join request';
  end if;
  if v_event.starts_at <= now() or v_event.status in ('completed', 'cancelled') then
    raise exception 'Event is no longer joinable';
  end if;
  if exists (
    select 1 from public.event_members
    where event_id = p_event_id and user_id = auth.uid()
  ) then
    return 'already_member';
  end if;

  select count(*) into v_member_count
  from public.event_members where event_id = p_event_id;
  if v_member_count >= v_event.capacity then
    update public.events set status = 'full', updated_at = now() where id = p_event_id;
    return 'full';
  end if;

  insert into public.event_members (event_id, user_id, role)
  values (p_event_id, auth.uid(), 'member');

  v_member_count := v_member_count + 1;
  update public.events
  set status = case when v_member_count >= capacity then 'full' else 'upcoming' end,
      updated_at = now()
  where id = p_event_id;

  return 'joined';
end;
$function$;

-- Keep membership changes behind RPCs. Leaving an active event also recalculates
-- its capacity status; past membership is retained for ratings and statistics.
create or replace function public.leave_event(p_event_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_catalog
as $function$
declare
  v_event public.events%rowtype;
  v_deleted integer;
  v_member_count integer;
begin
  if auth.uid() is null then raise exception 'Not authenticated' using errcode = '28000'; end if;

  perform pg_advisory_xact_lock(hashtextextended(p_event_id::text, 0));
  select * into v_event from public.events where id = p_event_id for update;
  if not found then raise exception 'Event not found'; end if;
  if v_event.host_id = auth.uid() then raise exception 'The host cannot leave their own event'; end if;
  if v_event.status not in ('upcoming', 'full') or v_event.starts_at <= now() then
    raise exception 'You can only leave an upcoming event';
  end if;

  delete from public.event_members
  where event_id = p_event_id and user_id = auth.uid() and role = 'member';
  get diagnostics v_deleted = row_count;
  if v_deleted = 0 then return 'not_member'; end if;

  select count(*) into v_member_count from public.event_members where event_id = p_event_id;
  update public.events
  set status = case when v_member_count >= capacity then 'full' else 'upcoming' end,
      updated_at = now()
  where id = p_event_id;

  return 'left';
end;
$function$;

-- Join requests are repeated through an upsert, so use a guarded RPC for that
-- transition before revoking direct UPDATE permission on the request table.
create or replace function public.request_event_join(p_event_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_catalog
as $function$
declare
  v_event public.events%rowtype;
begin
  if auth.uid() is null then raise exception 'Not authenticated' using errcode = '28000'; end if;

  select * into v_event from public.events where id = p_event_id for update;
  if not found then raise exception 'Event not found'; end if;
  if v_event.host_id = auth.uid() then return 'already_member'; end if;
  if v_event.visibility <> 'private' then raise exception 'This event is public; join it directly'; end if;
  if v_event.starts_at <= now() or v_event.status in ('completed', 'cancelled') then
    raise exception 'Event is no longer joinable';
  end if;
  if exists (select 1 from public.event_members where event_id = p_event_id and user_id = auth.uid()) then
    return 'already_member';
  end if;
  if v_event.status = 'full' then return 'full'; end if;

  insert into public.event_join_requests (event_id, user_id, status, decided_at)
  values (p_event_id, auth.uid(), 'pending', null)
  on conflict (event_id, user_id)
  do update set status = 'pending', decided_at = null;

  return 'requested';
end;
$function$;

-- decide_event_join_request is SECURITY DEFINER because it changes membership
-- and lifecycle state. Every operation is checked against auth.uid(), host,
-- event, request status, start time, and capacity.
create or replace function public.decide_event_join_request(
  p_request_id uuid,
  p_accept boolean
)
returns text
language plpgsql
security definer
set search_path = public, pg_catalog
as $function$
declare
  v_request public.event_join_requests%rowtype;
  v_event public.events%rowtype;
  v_event_id uuid;
  v_member_count integer;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  -- Read the event id without locking the request, then use a consistent
  -- event-first lock order shared by join, leave, cancellation, and editing.
  select event_id into v_event_id
  from public.event_join_requests
  where id = p_request_id;
  if not found then raise exception 'Join request not found'; end if;

  perform pg_advisory_xact_lock(hashtextextended(v_event_id::text, 0));
  select * into v_event
  from public.events
  where id = v_event_id
  for update;
  if not found then raise exception 'Event not found'; end if;

  select * into v_request
  from public.event_join_requests
  where id = p_request_id and event_id = v_event_id
  for update;
  if not found then raise exception 'Join request not found'; end if;
  if v_event.host_id <> auth.uid() then
    raise exception 'Only the event host can decide this request' using errcode = '42501';
  end if;
  if v_request.status <> 'pending' then return v_request.status; end if;
  if v_event.visibility <> 'private' or v_event.starts_at <= now()
     or v_event.status not in ('upcoming', 'full') then
    raise exception 'This event is no longer accepting join requests';
  end if;

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
    update public.events set status = 'full', updated_at = now() where id = v_event.id;
    update public.event_join_requests
    set status = 'declined', decided_at = now()
    where id = p_request_id;
    return 'full';
  end if;

  update public.event_join_requests
  set status = 'accepted', decided_at = now()
  where id = p_request_id;

  insert into public.event_members (event_id, user_id, role)
  values (v_event.id, v_request.user_id, 'member')
  on conflict (event_id, user_id) do nothing;

  select count(*) into v_member_count
  from public.event_members where event_id = v_event.id;

  update public.events
  set status = case when v_member_count >= capacity then 'full' else 'upcoming' end,
      updated_at = now()
  where id = v_event.id;

  return 'accepted';
end;
$function$;

-- Rating rows support two permissions: any event member may rate another
-- participant's performance (stars/note), while only the host may record
-- attendance and skill match. All ratings require a completed event.
create or replace function public.guard_rating_mutation()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $function$
declare
  v_event_id uuid;
  v_rater_id uuid;
  v_ratee_id uuid;
  v_host_id uuid;
  v_status text;
begin
  if tg_op = 'DELETE' then
    v_event_id := old.event_id;
    v_rater_id := old.rater_id;
    v_ratee_id := old.ratee_id;
  else
    v_event_id := new.event_id;
    v_rater_id := new.rater_id;
    v_ratee_id := new.ratee_id;
  end if;

  select host_id, status into v_host_id, v_status
  from public.events where id = v_event_id;
  if not found then raise exception 'Event not found'; end if;
  if auth.uid() is null or v_rater_id <> auth.uid() then
    raise exception 'You can only manage your own ratings' using errcode = '42501';
  end if;
  if v_status <> 'completed' then
    raise exception 'Ratings are only available after event completion';
  end if;
  if not exists (
    select 1 from public.event_members em
    where em.event_id = v_event_id and em.user_id = v_rater_id
  ) or not exists (
    select 1 from public.event_members em
    where em.event_id = v_event_id and em.user_id = v_ratee_id
  ) then
    raise exception 'Both players must be members of the event';
  end if;
  if v_rater_id = v_ratee_id then
    raise exception 'Players cannot rate themselves';
  end if;
  if tg_op = 'UPDATE' and (
    new.event_id <> old.event_id or
    new.rater_id <> old.rater_id or
    new.ratee_id <> old.ratee_id
  ) then
    raise exception 'A rating cannot be moved to another player or event';
  end if;

  if tg_op <> 'DELETE' then
    if v_rater_id <> v_host_id then
      if new.showed_up is distinct from true or new.skill_match is not null or new.score is null then
        raise exception 'Participants may submit star ratings only; attendance is host-only' using errcode = '42501';
      end if;
    elsif new.showed_up and (new.score is null or new.score < 1 or new.score > 5) then
      raise exception 'The host must rate each player who attended';
    elsif not new.showed_up and (new.score is not null or new.skill_match is not null) then
      raise exception 'A player marked absent cannot have a score or skill-match rating';
    end if;
    new.note := left(nullif(btrim(new.note), ''), 500);
    new.updated_at := now();
  end if;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$function$;

drop trigger if exists ratings_guard_host_mutations on public.ratings;
create trigger ratings_guard_host_mutations
before insert or update or delete on public.ratings
for each row execute function public.guard_rating_mutation();

-- Keep the legacy RPC name used by the browser, but put all validation and
-- attendance writes behind one transaction-safe SECURITY DEFINER function.
-- Dropping known legacy signatures avoids ambiguous PostgREST overloads.
drop function if exists public.submit_rating(uuid, uuid, integer, boolean, boolean, text);
drop function if exists public.submit_rating(uuid, uuid, smallint, boolean, boolean, text);
create function public.submit_rating(
  p_event_id uuid,
  p_ratee_id uuid,
  p_score integer,
  p_showed_up boolean,
  p_skill_match boolean,
  p_note text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_catalog
as $function$
declare
  v_rater_id uuid := auth.uid();
  v_host_id uuid;
  v_status text;
  v_rating_id uuid;
begin
  if v_rater_id is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  select host_id, status into v_host_id, v_status
  from public.events where id = p_event_id for update;
  if not found then raise exception 'Event not found'; end if;
  if v_status <> 'completed' then
    raise exception 'Ratings are only available after event completion';
  end if;
  if v_rater_id = p_ratee_id then raise exception 'Players cannot rate themselves'; end if;
  if not exists (select 1 from public.event_members where event_id = p_event_id and user_id = v_rater_id)
     or not exists (select 1 from public.event_members where event_id = p_event_id and user_id = p_ratee_id) then
    raise exception 'Both players must be members of the event' using errcode = '42501';
  end if;

  if v_rater_id = v_host_id then
    if p_showed_up then
      if p_score is null or p_score < 1 or p_score > 5 then
        raise exception 'Select a star rating for each player who attended';
      end if;
    elsif p_score is not null or p_skill_match is not null then
      raise exception 'A player marked absent cannot have a score or skill-match rating';
    end if;
    update public.event_members
    set showed_up = p_showed_up
    where event_id = p_event_id and user_id = p_ratee_id;
  else
    if p_showed_up is distinct from true or p_skill_match is not null or p_score is null or p_score < 1 or p_score > 5 then
      raise exception 'Participants can submit star ratings only' using errcode = '42501';
    end if;
  end if;

  insert into public.ratings (event_id, rater_id, ratee_id, score, showed_up, skill_match, note)
  values (p_event_id, v_rater_id, p_ratee_id, p_score::smallint, p_showed_up, p_skill_match, left(nullif(btrim(p_note), ''), 500))
  on conflict (event_id, rater_id, ratee_id)
  do update set
    score = excluded.score,
    showed_up = excluded.showed_up,
    skill_match = excluded.skill_match,
    note = excluded.note,
    updated_at = now()
  returning id into v_rating_id;

  return v_rating_id;
end;
$function$;

-- Event requests can only be changed by the event host. Requesters may create a
-- pending request, but cannot promote themselves to accepted/declined/cancelled.
drop policy if exists event_join_requests_update_self_or_host on public.event_join_requests;
drop policy if exists event_join_requests_update_host_only on public.event_join_requests;
create policy event_join_requests_update_host_only
on public.event_join_requests
for update to authenticated
using (exists (
  select 1 from public.events e
  where e.id = event_join_requests.event_id and e.host_id = auth.uid()
))
with check (exists (
  select 1 from public.events e
  where e.id = event_join_requests.event_id and e.host_id = auth.uid()
));

-- Membership inserts must respect capacity even if the client bypasses join_event.
create or replace function public.guard_event_member_insert()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $function$
declare
  v_event public.events%rowtype;
  v_member_count integer;
begin
  perform pg_advisory_xact_lock(hashtextextended(new.event_id::text, 0));
  select * into v_event from public.events where id = new.event_id for update;
  if not found then raise exception 'Event not found'; end if;

  -- The event insert trigger creates the host row on the creator's behalf.
  -- Do not treat a missing auth.uid() as a successful authorization check.
  if new.role = 'host' and new.user_id = v_event.host_id and auth.uid() = v_event.host_id then
    return new;
  end if;
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;
  if v_event.status not in ('upcoming', 'full') or v_event.starts_at <= now() then
    raise exception 'This event is no longer accepting members';
  end if;

  if auth.uid() <> v_event.host_id then
    if new.user_id <> auth.uid() or new.role <> 'member' or v_event.visibility <> 'public' then
      raise exception 'Join private events by requesting access';
    end if;
  end if;

  select count(*) into v_member_count
  from public.event_members where event_id = new.event_id;
  if v_member_count >= v_event.capacity then raise exception 'Event is full'; end if;
  return new;
end;
$function$;

drop trigger if exists event_members_capacity_guard on public.event_members;
create trigger event_members_capacity_guard
before insert on public.event_members
for each row execute function public.guard_event_member_insert();

-- Prevent an edit from reducing capacity below the existing membership count.
create or replace function public.guard_event_capacity_update()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $function$
declare
  v_member_count integer;
begin
  if new.capacity < old.capacity then
    select count(*) into v_member_count
    from public.event_members where event_id = old.id;
    if new.capacity < v_member_count then
      raise exception 'Capacity cannot be lower than the current number of players';
    end if;
  end if;
  return new;
end;
$function$;

drop trigger if exists events_capacity_not_below_members on public.events;
create trigger events_capacity_not_below_members
before update of capacity on public.events
for each row execute function public.guard_event_capacity_update();

-- Writes must go through the validated RPCs. These revocations prevent direct
-- REST updates from bypassing the atomic event lifecycle and rating rules.
revoke insert, update, delete on table public.event_members from public, anon, authenticated;
revoke delete on table public.events from public, anon, authenticated;
revoke insert, update, delete on table public.event_join_requests from public, anon, authenticated;
revoke insert, update, delete on table public.ratings from public, anon, authenticated;
grant select on table public.ratings to authenticated;

-- Keep the safe RPCs callable by authenticated users only.
revoke all on function public.complete_event(uuid) from public, anon;
revoke all on function public.cancel_event(uuid) from public, anon;
revoke all on function public.mark_host_ratings_complete(uuid) from public, anon;
revoke all on function public.decide_event_join_request(uuid, boolean) from public, anon;
revoke all on function public.join_event(uuid) from public, anon;
revoke all on function public.leave_event(uuid) from public, anon;
revoke all on function public.request_event_join(uuid) from public, anon;
revoke all on function public.guard_rating_mutation() from public, anon, authenticated;
revoke all on function public.submit_rating(uuid, uuid, integer, boolean, boolean, text) from public, anon;
revoke all on function public.guard_event_member_insert() from public, anon, authenticated;
revoke all on function public.guard_event_capacity_update() from public, anon, authenticated;
grant execute on function public.complete_event(uuid) to authenticated;
grant execute on function public.cancel_event(uuid) to authenticated;
grant execute on function public.mark_host_ratings_complete(uuid) to authenticated;
grant execute on function public.decide_event_join_request(uuid, boolean) to authenticated;
grant execute on function public.join_event(uuid) to authenticated;
grant execute on function public.leave_event(uuid) to authenticated;
grant execute on function public.request_event_join(uuid) to authenticated;
grant execute on function public.submit_rating(uuid, uuid, integer, boolean, boolean, text) to authenticated;
