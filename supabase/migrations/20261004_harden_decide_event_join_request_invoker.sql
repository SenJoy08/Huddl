-- Keep decide_event_join_request() fully RLS-controlled under SECURITY INVOKER.
-- The request row already exists, so update it instead of INSERT ... ON CONFLICT.

create or replace function public.decide_event_join_request(
  p_request_id uuid,
  p_accept boolean
)
returns text
language plpgsql
security invoker
set search_path = public, pg_catalog
as $function$
declare
  v_request public.event_join_requests%rowtype;
  v_event public.events%rowtype;
  v_member_count integer;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_request
  from public.event_join_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Join request not found';
  end if;

  select * into v_event
  from public.events
  where id = v_request.event_id
  for update;

  if not found then
    raise exception 'Event not found';
  end if;

  if v_event.host_id <> auth.uid() then
    raise exception 'Only the event host can decide this request';
  end if;

  if v_request.status <> 'pending' then
    return v_request.status;
  end if;

  if not p_accept then
    update public.event_join_requests
    set status = 'declined',
        decided_at = now()
    where id = p_request_id;
    return 'declined';
  end if;

  select count(*) into v_member_count
  from public.event_members
  where event_id = v_event.id;

  if v_member_count >= v_event.capacity then
    update public.events
    set status = 'full',
        updated_at = now()
    where id = v_event.id;
    raise exception 'Event is full';
  end if;

  update public.event_join_requests
  set status = 'accepted',
      decided_at = now()
  where id = p_request_id;

  insert into public.event_members (event_id, user_id, role)
  values (v_event.id, v_request.user_id, 'member')
  on conflict (event_id, user_id) do nothing;

  v_member_count := v_member_count + 1;

  update public.events
  set status = case when v_member_count >= capacity then 'full' else 'upcoming' end,
      updated_at = now()
  where id = v_event.id;

  return 'accepted';
end;
$function$;
