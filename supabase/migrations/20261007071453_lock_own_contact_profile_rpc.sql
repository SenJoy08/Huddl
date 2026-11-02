drop function if exists public.get_own_contact_profile();

create or replace function private.get_own_contact_profile()
returns jsonb
language sql
security definer
stable
set search_path = public, pg_catalog
as $function$
  select jsonb_build_object(
    'phone', p.phone,
    'contact_visibility', p.contact_visibility
  )
  from public.profiles p
  where p.id = auth.uid();
$function$;

revoke all on function private.get_own_contact_profile() from public, anon, authenticated;
grant execute on function private.get_own_contact_profile() to authenticated;

create or replace function public.get_own_contact_profile()
returns jsonb
language sql
stable
set search_path = public, private, pg_catalog
as $function$
  select private.get_own_contact_profile();
$function$;

revoke all on function public.get_own_contact_profile() from public, anon, authenticated;
grant execute on function public.get_own_contact_profile() to authenticated;;
