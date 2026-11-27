
create or replace function public.send_friend_request(p_receiver_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_existing_status text;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if p_receiver_id is null or p_receiver_id = auth.uid() then
    raise exception 'Invalid friend request target';
  end if;

  if not exists (select 1 from public.profiles where id = p_receiver_id) then
    raise exception 'User not found';
  end if;

  if exists (
    select 1
    from public.friendships
    where (user_a = least(auth.uid(), p_receiver_id) and user_b = greatest(auth.uid(), p_receiver_id))
       or (user_a = greatest(auth.uid(), p_receiver_id) and user_b = least(auth.uid(), p_receiver_id))
  ) then
    return 'already_friend';
  end if;

  select status
  into v_existing_status
  from public.friend_requests
  where sender_id = auth.uid()
    and receiver_id = p_receiver_id
    and status = 'pending'
  order by created_at desc
  limit 1;

  if v_existing_status = 'pending' then
    return 'already_pending';
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

  insert into public.friend_requests (sender_id, receiver_id, status)
  values (auth.uid(), p_receiver_id, 'pending');

  return 'sent';
end;
$$;

create or replace function public.respond_friend_request(
  p_request_id uuid,
  p_accept boolean
)
returns text
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_request public.friend_requests%rowtype;
  v_user_a uuid;
  v_user_b uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select *
  into v_request
  from public.friend_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Friend request not found';
  end if;

  if v_request.receiver_id <> auth.uid() then
    raise exception 'Only the recipient can decide this request';
  end if;

  if v_request.status <> 'pending' then
    return v_request.status;
  end if;

  if not p_accept then
    update public.friend_requests
    set status = 'declined', decided_at = now()
    where id = p_request_id;
    return 'declined';
  end if;

  v_user_a := least(v_request.sender_id, v_request.receiver_id);
  v_user_b := greatest(v_request.sender_id, v_request.receiver_id);

  insert into public.friendships (user_a, user_b)
  values (v_user_a, v_user_b)
  on conflict do nothing;

  update public.friend_requests
  set status = 'accepted', decided_at = now()
  where id = p_request_id;

  return 'accepted';
end;
$$;

create or replace function public.remove_friend(p_friend_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_deleted integer;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  delete from public.friendships
  where (user_a = least(auth.uid(), p_friend_id) and user_b = greatest(auth.uid(), p_friend_id))
     or (user_a = greatest(auth.uid(), p_friend_id) and user_b = least(auth.uid(), p_friend_id));

  get diagnostics v_deleted = row_count;

  if v_deleted = 0 then
    return 'not_friends';
  end if;

  return 'removed';
end;
$$;

revoke all on function public.send_friend_request(uuid) from public, anon;
revoke all on function public.respond_friend_request(uuid,boolean) from public, anon;
revoke all on function public.remove_friend(uuid) from public, anon;

grant execute on function public.send_friend_request(uuid) to authenticated;
grant execute on function public.respond_friend_request(uuid,boolean) to authenticated;
grant execute on function public.remove_friend(uuid) to authenticated;
;
