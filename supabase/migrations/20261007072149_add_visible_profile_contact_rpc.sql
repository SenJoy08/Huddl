create or replace function private.get_visible_profile_contact(target_user uuid)
returns text
language plpgsql
security definer
stable
set search_path = public, pg_catalog
as $function$
declare
  v_phone text;
  v_visibility text;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select phone, contact_visibility
  into v_phone, v_visibility
  from public.profiles
  where id = target_user;

  if not found then
    return null;
  end if;

  if target_user = auth.uid() then
    return v_phone;
  end if;

  if v_visibility = 'everyone' then
    return v_phone;
  end if;

  if v_visibility = 'friends'
     and exists (
       select 1
       from public.friendships f
       where (f.user_a = auth.uid() and f.user_b = target_user)
          or (f.user_a = target_user and f.user_b = auth.uid())
     ) then
    return v_phone;
  end if;

  return null;
end;
$function$;

revoke all on function private.get_visible_profile_contact(uuid) from public, anon, authenticated;
grant execute on function private.get_visible_profile_contact(uuid) to authenticated;

create or replace function public.get_visible_profile_contact(target_user uuid)
returns text
language sql
stable
security invoker
set search_path = public, private, pg_catalog
as $function$
  select private.get_visible_profile_contact(target_user);
$function$;

revoke all on function public.get_visible_profile_contact(uuid) from public, anon, authenticated;
grant execute on function public.get_visible_profile_contact(uuid) to authenticated;;
