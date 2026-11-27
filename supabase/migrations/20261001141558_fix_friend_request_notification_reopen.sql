
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
        coalesce(v_name, 'Someone') || ' sent you a friend request.',
        null,
        new.id
      );
    end if;
    return new;
  end if;

  if tg_op = 'UPDATE' and old.status is distinct from new.status then
    if new.status = 'pending' then
      v_recipient_id := new.receiver_id;
      v_type := 'friend_request_received';
      v_message := coalesce(v_name, 'Someone') || ' sent you a friend request.';
    elsif new.status = 'accepted' then
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
      case when new.status = 'pending' then new.sender_id else new.receiver_id end,
      v_type,
      v_message,
      null,
      new.id
    );
  end if;

  return new;
end;
$function$;
;
