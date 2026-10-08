-- Keep the data-aggregating implementation privileged and internal, while
-- leaving the public API function SECURITY INVOKER so the exposed RPC itself
-- is not a SECURITY DEFINER endpoint.

create or replace function private.get_public_player_stats_internal(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $function$
declare
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if not exists (
    select 1
    from public.profiles
    where id = p_user_id
  ) then
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
      select case
        when count(*) = 0 then null
        else round(avg(case when showed_up then 100.0 else 0.0 end))::int
      end
      from attendance_rows
    ),
    'sports', coalesce(
      (select jsonb_agg(jsonb_build_object('name', name, 'games', games))
       from sports_breakdown),
      '[]'::jsonb
    )
  )
  into v_result;

  return v_result;
end;
$function$;

grant execute on function private.get_public_player_stats_internal(uuid)
to authenticated;

create or replace function public.get_public_player_stats(p_user_id uuid)
returns jsonb
language sql
stable
security invoker
set search_path = public, pg_catalog
as $function$
  select private.get_public_player_stats_internal(p_user_id);
$function$;
