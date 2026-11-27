
create or replace function public.submit_rating(
  p_event_id uuid,
  p_ratee_id uuid,
  p_score smallint,
  p_showed_up boolean,
  p_skill_match boolean,
  p_note text default null
)
returns uuid
language plpgsql
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v_rating_id uuid;
  v_is_host boolean;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if p_event_id is null or p_ratee_id is null or p_ratee_id = auth.uid() then
    raise exception 'Invalid rating target';
  end if;

  select (host_id = auth.uid())
  into v_is_host
  from public.events
  where id = p_event_id
    and status = 'completed';

  if v_is_host is null then
    raise exception 'Ratings are only available after an event is completed';
  end if;

  if not exists (
    select 1 from public.event_members
    where event_id = p_event_id and user_id = auth.uid()
  ) then
    raise exception 'You were not a participant in this event';
  end if;

  if not exists (
    select 1 from public.event_members
    where event_id = p_event_id and user_id = p_ratee_id
  ) then
    raise exception 'The player was not a participant in this event';
  end if;

  if not v_is_host then
    p_showed_up := true;
  end if;

  if p_showed_up and (p_score is null or p_score < 1 or p_score > 5) then
    raise exception 'A 1 to 5 rating is required for players who showed up';
  end if;

  if not p_showed_up then
    p_score := null;
    p_skill_match := null;
  end if;

  insert into public.ratings (
    event_id, rater_id, ratee_id, score, showed_up, skill_match, note
  )
  values (
    p_event_id, auth.uid(), p_ratee_id, p_score, p_showed_up, p_skill_match,
    nullif(btrim(coalesce(p_note, '')), '')
  )
  on conflict (event_id, rater_id, ratee_id)
  do update set
    score = excluded.score,
    showed_up = excluded.showed_up,
    skill_match = excluded.skill_match,
    note = excluded.note,
    updated_at = now()
  returning id into v_rating_id;

  if v_is_host then
    update public.event_members
    set showed_up = p_showed_up
    where event_id = p_event_id
      and user_id = p_ratee_id;
  end if;

  return v_rating_id;
end;
$function$;

revoke all on function public.submit_rating(uuid, uuid, smallint, boolean, boolean, text) from public;
grant execute on function public.submit_rating(uuid, uuid, smallint, boolean, boolean, text) to authenticated;

create or replace function public.get_public_player_stats(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if not exists (select 1 from public.profiles where id = p_user_id) then
    raise exception 'Player profile not found';
  end if;

  with completed_events as (
    select distinct e.id, e.host_id
    from public.events e
    join public.event_members em on em.event_id = e.id
    where em.user_id = p_user_id
      and e.event_type_code = 'sport'
      and e.status = 'completed'
  ),
  received_ratings as (
    select r.score
    from public.ratings r
    join completed_events ce on ce.id = r.event_id
    where r.ratee_id = p_user_id
      and r.showed_up = true
      and r.score is not null
  ),
  attendance_rows as (
    select em.showed_up
    from public.event_members em
    join completed_events ce on ce.id = em.event_id
    where em.user_id = p_user_id
      and em.showed_up is not null
  ),
  sports_breakdown as (
    select s.name, count(distinct ce.id)::int as games
    from completed_events ce
    join public.event_sports es on es.event_id = ce.id
    join public.sports s on s.id = es.sport_id
    group by s.name
    order by games desc, s.name
  )
  select jsonb_build_object(
    'games', (select count(*)::int from completed_events),
    'hosted', (select count(*)::int from completed_events where host_id = p_user_id),
    'rating', (select round(avg(score)::numeric, 1) from received_ratings),
    'attendance', (
      select case when count(*) = 0 then null
        else round(avg(case when showed_up then 100.0 else 0.0 end))::int
      end
      from attendance_rows
    ),
    'sports', coalesce(
      (select jsonb_agg(jsonb_build_object('name', name, 'games', games)) from sports_breakdown),
      '[]'::jsonb
    )
  )
  into v_result;

  return v_result;
end;
$function$;

revoke all on function public.get_public_player_stats(uuid) from public;
grant execute on function public.get_public_player_stats(uuid) to authenticated;
;
