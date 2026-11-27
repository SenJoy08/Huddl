-- Save notification preferences and contact visibility in one transaction.
-- The caller identity always comes from the JWT; no user id is accepted from the client.

create or replace function public.save_user_settings(
  p_event_updates boolean,
  p_friend_updates boolean,
  p_rating_reminders boolean,
  p_contact_visible boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  if p_event_updates is null
     or p_friend_updates is null
     or p_rating_reminders is null
     or p_contact_visible is null then
    raise exception 'All settings values are required';
  end if;

  update public.profiles
  set contact_visibility = case
    when p_contact_visible then 'friends'
    else 'nobody'
  end
  where id = v_user_id;

  if not found then
    raise exception 'Profile not found';
  end if;

  insert into public.notification_preferences (
    user_id,
    event_updates,
    friend_updates,
    rating_reminders
  )
  values (
    v_user_id,
    p_event_updates,
    p_friend_updates,
    p_rating_reminders
  )
  on conflict (user_id)
  do update set
    event_updates = excluded.event_updates,
    friend_updates = excluded.friend_updates,
    rating_reminders = excluded.rating_reminders,
    updated_at = now();
end;
$function$;

revoke all on function public.save_user_settings(boolean, boolean, boolean, boolean)
from public, anon;
grant execute on function public.save_user_settings(boolean, boolean, boolean, boolean)
to authenticated;
