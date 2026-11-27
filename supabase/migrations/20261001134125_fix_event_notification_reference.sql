
create or replace function public.create_notification(
  p_recipient_id uuid,
  p_actor_id uuid,
  p_type text,
  p_message text,
  p_event_id uuid default null,
  p_friend_request_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v_notification_id uuid;
  v_category text;
  v_friend_request_id uuid := p_friend_request_id;
begin
  if p_recipient_id is null or p_message is null or btrim(p_message) = '' then
    return null;
  end if;

  v_category := case
    when p_type like 'friend_%' then 'friend'
    when p_type = 'rating_reminder' then 'rating'
    else 'event'
  end;

  if not public.notification_preference_enabled(p_recipient_id, v_category) then
    return null;
  end if;

  if p_actor_id is not null and p_actor_id = p_recipient_id then
    return null;
  end if;

  if v_friend_request_id is not null
     and not exists (
       select 1
       from public.friend_requests
       where id = v_friend_request_id
     ) then
    v_friend_request_id := null;
  end if;

  insert into public.notifications (
    recipient_id,
    actor_id,
    type,
    event_id,
    friend_request_id,
    message
  )
  values (
    p_recipient_id,
    p_actor_id,
    p_type,
    p_event_id,
    v_friend_request_id,
    p_message
  )
  returning id into v_notification_id;

  return v_notification_id;
end;
$function$;

create or replace function public.notify_event_join_request_changes()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v_actor_name text;
  v_host_id uuid;
  v_event_title text;
begin
  if tg_op = 'INSERT' then
    select e.host_id, e.title
    into v_host_id, v_event_title
    from public.events e
    where e.id = new.event_id;

    select coalesce(nullif(display_name, ''), 'Someone')
    into v_actor_name
    from public.profiles
    where id = new.user_id;

    if new.status = 'pending' then
      perform public.create_notification(
        v_host_id,
        new.user_id,
        'event_join_request_received',
        v_actor_name || ' wants to join ' || coalesce(v_event_title, 'your event') || '.',
        new.event_id,
        null
      );
    end if;

    return new;
  end if;

  if tg_op = 'UPDATE' and old.status is distinct from new.status then
    select e.host_id, e.title
    into v_host_id, v_event_title
    from public.events e
    where e.id = new.event_id;

    if new.status = 'accepted' then
      perform public.create_notification(
        new.user_id,
        v_host_id,
        'event_join_request_accepted',
        'Your request to join ' || coalesce(v_event_title, 'the event') || ' was accepted.',
        new.event_id,
        null
      );
    elsif new.status = 'declined' then
      perform public.create_notification(
        new.user_id,
        v_host_id,
        'event_join_request_declined',
        'Your request to join ' || coalesce(v_event_title, 'the event') || ' was declined.',
        new.event_id,
        null
      );
    end if;
  end if;

  return new;
end;
$function$;
;
