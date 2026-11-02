-- Keep public profile discovery intact while preventing authenticated clients
-- from selecting private contact fields from other users' profile rows.
revoke select (phone, contact_visibility) on table public.profiles from anon, authenticated;

create or replace function public.get_own_contact_profile()
returns jsonb
language sql
security definer
set search_path = public, pg_catalog
as $$
  select jsonb_build_object(
    'phone', p.phone,
    'contact_visibility', p.contact_visibility
  )
  from public.profiles p
  where p.id = auth.uid();
$$;

revoke all on function public.get_own_contact_profile() from public, anon, authenticated;
grant execute on function public.get_own_contact_profile() to authenticated;;
