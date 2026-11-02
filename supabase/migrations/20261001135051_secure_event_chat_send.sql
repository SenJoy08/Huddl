
create or replace function public.send_event_message(
  p_event_id uuid,
  p_body text
)
returns uuid
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v_message_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if p_event_id is null or p_body is null or btrim(p_body) = '' then
    raise exception 'Message cannot be empty';
  end if;

  if not exists (
    select 1
    from public.events e
    join public.event_members em on em.event_id = e.id
    where e.id = p_event_id
      and em.user_id = auth.uid()
      and e.status not in ('completed', 'cancelled')
  ) then
    raise exception 'You cannot chat in this event';
  end if;

  insert into public.event_messages(event_id, sender_id, body)
  values (p_event_id, auth.uid(), btrim(p_body))
  returning id into v_message_id;

  return v_message_id;
end;
$function$;

revoke execute on function public.send_event_message(uuid, text) from public;
grant execute on function public.send_event_message(uuid, text) to authenticated;
;
