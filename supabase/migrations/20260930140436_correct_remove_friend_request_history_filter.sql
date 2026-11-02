
create or replace function public.remove_friend(p_friend_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_catalog
as $function$
declare
  v_deleted integer;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if p_friend_id is null or p_friend_id = auth.uid() then
    raise exception 'Invalid friend';
  end if;

  delete from public.friendships
  where user_a = least(auth.uid(), p_friend_id)
    and user_b = greatest(auth.uid(), p_friend_id);

  get diagnostics v_deleted = row_count;

  if v_deleted = 0 then
    return 'not_friends';
  end if;

  update public.friend_requests
  set status = 'cancelled',
      decided_at = now()
  where status = 'accepted'
    and (
      (sender_id = auth.uid() and receiver_id = p_friend_id)
      or
      (sender_id = p_friend_id and receiver_id = auth.uid())
    );

  return 'removed';
end;
$function$;

grant execute on function public.remove_friend(uuid) to authenticated;
;
