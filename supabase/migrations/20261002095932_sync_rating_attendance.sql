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
  v_has_rating boolean;
  v_anyone_saw_player boolean;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if p_event_id is null or p_ratee_id is null or p_ratee_id = auth.uid() then
    raise exception 'Invalid rating target';
  end if;

  if not exists (
    select 1 from public.events
    where id = p_event_id
      and status = 'completed'
  ) then
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

  select
    count(*) > 0,
    bool_or(showed_up)
  into v_has_rating, v_anyone_saw_player
  from public.ratings
  where event_id = p_event_id
    and ratee_id = p_ratee_id
    and showed_up is not null;

  update public.event_members
  set showed_up = case
    when v_has_rating then coalesce(v_anyone_saw_player, false)
    else null
  end
  where event_id = p_event_id
    and user_id = p_ratee_id;

  return v_rating_id;
end;
$function$;;
