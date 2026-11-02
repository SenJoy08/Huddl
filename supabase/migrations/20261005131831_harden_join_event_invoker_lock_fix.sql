
create or replace function public.join_event(p_event_id uuid)
returns text
language plpgsql
security invoker
set search_path = public, pg_catalog
as $function$
declare
  v_event public.events%rowtype;
  v_member_count integer;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  -- Serialize joins for this event without requiring UPDATE privilege on
  -- the events table. FOR UPDATE cannot be used under the host-only UPDATE RLS
  -- policy, so use a transaction-scoped advisory lock instead.
  perform pg_advisory_xact_lock(hashtextextended(p_event_id::text, 0));

  select *
  into v_event
  from public.events
  where id = p_event_id;

  if not found then
    raise exception 'Event not found';
  end if;

  if v_event.visibility <> 'public' then
    raise exception 'Private events require a join request';
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

  select count(*) into v_member_count
  from public.event_members
  where event_id = p_event_id;

  if v_member_count >= v_event.capacity then
    return 'full';
  end if;

  insert into public.event_members (event_id, user_id, role)
  values (p_event_id, auth.uid(), 'member');

  return 'joined';
end;
$function$;
;
