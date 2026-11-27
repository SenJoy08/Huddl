
create or replace function public.notification_preference_enabled(
  p_user_id uuid,
  p_category text
)
returns boolean
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v_enabled boolean;
begin
  if p_user_id is null then
    return false;
  end if;

  select case p_category
    when 'friend' then friend_updates
    when 'event' then event_updates
    when 'rating' then rating_reminders
    else true
  end
  into v_enabled
  from public.notification_preferences
  where user_id = p_user_id;

  return coalesce(v_enabled, true);
end;
$function$;

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
    p_friend_request_id,
    p_message
  )
  returning id into v_notification_id;

  return v_notification_id;
end;
$function$;

create or replace function public.notify_friend_request_changes()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v_name text;
  v_recipient_id uuid;
  v_type text;
  v_message text;
begin
  select coalesce(nullif(display_name, ''), 'Someone')
  into v_name
  from public.profiles
  where id = coalesce(new.sender_id, old.sender_id);

  if tg_op = 'INSERT' then
    if new.status = 'pending' then
      perform public.create_notification(
        new.receiver_id,
        new.sender_id,
        'friend_request_received',
        v_name || ' sent you a friend request.',
        null,
        new.id
      );
    end if;
    return new;
  end if;

  if tg_op = 'UPDATE' and old.status is distinct from new.status then
    if new.status = 'accepted' then
      v_recipient_id := new.sender_id;
      v_type := 'friend_request_accepted';
      v_message := coalesce(v_name, 'Someone') || ' accepted your friend request.';
    elsif new.status = 'declined' then
      v_recipient_id := new.sender_id;
      v_type := 'friend_request_declined';
      v_message := coalesce(v_name, 'Someone') || ' declined your friend request.';
    else
      return new;
    end if;

    perform public.create_notification(
      v_recipient_id,
      new.receiver_id,
      v_type,
      v_message,
      null,
      new.id
    );
  end if;

  return new;
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
  v_recipient_id uuid;
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
        new.id
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
        new.id
      );
    elsif new.status = 'declined' then
      perform public.create_notification(
        new.user_id,
        v_host_id,
        'event_join_request_declined',
        'Your request to join ' || coalesce(v_event_title, 'the event') || ' was declined.',
        new.event_id,
        new.id
      );
    end if;
  end if;

  return new;
end;
$function$;

create or replace function public.notify_event_member_added()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v_host_id uuid;
  v_event_title text;
  v_member_name text;
begin
  if new.role = 'host' then
    return new;
  end if;

  select e.host_id, e.title
  into v_host_id, v_event_title
  from public.events e
  where e.id = new.event_id;

  if v_host_id is null or v_host_id = new.user_id then
    return new;
  end if;

  if exists (
    select 1
    from public.event_join_requests r
    where r.event_id = new.event_id
      and r.user_id = new.user_id
      and r.status = 'accepted'
  ) then
    return new;
  end if;

  select coalesce(nullif(display_name, ''), 'Someone')
  into v_member_name
  from public.profiles
  where id = new.user_id;

  perform public.create_notification(
    v_host_id,
    new.user_id,
    'event_member_joined',
    v_member_name || ' joined ' || coalesce(v_event_title, 'your event') || '.',
    new.event_id,
    null
  );

  return new;
end;
$function$;

create or replace function public.notify_event_changes()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v_event_title text;
  v_message text;
  v_member record;
begin
  if tg_op <> 'UPDATE' then
    return new;
  end if;

  if old.status is distinct from new.status and new.status = 'cancelled' then
    v_event_title := coalesce(new.title, 'An event');
    for v_member in
      select em.user_id
      from public.event_members em
      where em.event_id = new.id
        and em.user_id <> new.host_id
    loop
      perform public.create_notification(
        v_member.user_id,
        new.host_id,
        'event_cancelled',
        v_event_title || ' was cancelled.',
        new.id,
        null
      );
    end loop;

    return new;
  end if;

  if old.status is distinct from new.status and new.status = 'completed' then
    v_event_title := coalesce(new.title, 'Your game');
    for v_member in
      select em.user_id
      from public.event_members em
      where em.event_id = new.id
    loop
      perform public.create_notification(
        v_member.user_id,
        new.host_id,
        'rating_reminder',
        'Rate the players from ' || v_event_title || '.',
        new.id,
        null
      );
    end loop;

    return new;
  end if;

  if (
    old.title is distinct from new.title
    or old.description is distinct from new.description
    or old.starts_at is distinct from new.starts_at
    or old.location_name is distinct from new.location_name
    or old.capacity is distinct from new.capacity
    or old.visibility is distinct from new.visibility
  ) then
    v_event_title := coalesce(new.title, 'Your event');
    v_message := v_event_title || ' was updated.';
    for v_member in
      select em.user_id
      from public.event_members em
      where em.event_id = new.id
        and em.user_id <> new.host_id
    loop
      perform public.create_notification(
        v_member.user_id,
        new.host_id,
        'event_updated',
        v_message,
        new.id,
        null
      );
    end loop;
  end if;

  return new;
end;
$function$;

drop trigger if exists trg_notifications_friend_requests on public.friend_requests;
create trigger trg_notifications_friend_requests
after insert or update of status on public.friend_requests
for each row execute function public.notify_friend_request_changes();

drop trigger if exists trg_notifications_event_join_requests on public.event_join_requests;
create trigger trg_notifications_event_join_requests
after insert or update of status on public.event_join_requests
for each row execute function public.notify_event_join_request_changes();

drop trigger if exists trg_notifications_event_members on public.event_members;
create trigger trg_notifications_event_members
after insert on public.event_members
for each row execute function public.notify_event_member_added();

drop trigger if exists trg_notifications_events on public.events;
create trigger trg_notifications_events
after update on public.events
for each row execute function public.notify_event_changes();

create index if not exists notifications_recipient_created_at_idx
on public.notifications (recipient_id, created_at desc);

create index if not exists notifications_recipient_unread_idx
on public.notifications (recipient_id, read, created_at desc);

do $do$
begin
  if exists (select 1 from pg_catalog.pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1
       from pg_catalog.pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'notifications'
     ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end
$do$;
;
