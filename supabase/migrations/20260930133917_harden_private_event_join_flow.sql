
alter table public.event_join_requests
  add constraint event_join_requests_event_user_key unique (event_id, user_id);

create or replace function public.request_event_join(p_event_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_catalog
as $function$
declare
  v_event public.events%rowtype;
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

  if v_event.host_id = auth.uid() then
    return 'already_member';
  end if;

  if v_event.visibility <> 'private' then
    raise exception 'This event is public; join it directly';
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

  if v_event.status = 'full' or (
    select count(*)
    from public.event_members
    where event_id = p_event_id
  ) >= v_event.capacity then
    update public.events
    set status = 'full',
        updated_at = now()
    where id = p_event_id;
    return 'full';
  end if;

  insert into public.event_join_requests (
    event_id, user_id, status, decided_at
  )
  values (
    p_event_id, auth.uid(), 'pending', null
  )
  on conflict (event_id, user_id)
  do update
    set status = 'pending',
        decided_at = null;

  return 'requested';
end;
$function$;

grant execute on function public.request_event_join(uuid) to authenticated;
;
