
create or replace function public.send_friend_request(p_receiver_id uuid)
returns text
language plpgsql
set search_path = public, pg_catalog
as $function$
declare
  v_existing_id uuid;
  v_existing_status text;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if p_receiver_id is null or p_receiver_id = auth.uid() then
    raise exception 'Invalid friend request target';
  end if;

  if not exists (
    select 1
    from public.profiles
    where id = p_receiver_id
  ) then
    raise exception 'User not found';
  end if;

  if exists (
    select 1
    from public.friendships
    where user_a = least(auth.uid(), p_receiver_id)
      and user_b = greatest(auth.uid(), p_receiver_id)
  ) then
    return 'already_friend';
  end if;

  select id, status
  into v_existing_id, v_existing_status
  from public.friend_requests
  where sender_id = auth.uid()
    and receiver_id = p_receiver_id
  order by created_at desc
  limit 1;

  if v_existing_status = 'pending' then
    return 'already_pending';
  end if;

  if v_existing_status = 'accepted' then
    insert into public.friendships (user_a, user_b)
    values (
      least(auth.uid(), p_receiver_id),
      greatest(auth.uid(), p_receiver_id)
    )
    on conflict do nothing;

    return 'already_friend';
  end if;

  if exists (
    select 1
    from public.friend_requests
    where sender_id = p_receiver_id
      and receiver_id = auth.uid()
      and status = 'pending'
  ) then
    return 'incoming_pending';
  end if;

  if v_existing_id is not null then
    update public.friend_requests
    set status = 'pending',
        decided_at = null,
        created_at = now()
    where id = v_existing_id;

    return 'sent';
  end if;

  insert into public.friend_requests (
    sender_id,
    receiver_id,
    status
  )
  values (
    auth.uid(),
    p_receiver_id,
    'pending'
  );

  return 'sent';
end;
$function$;
;
