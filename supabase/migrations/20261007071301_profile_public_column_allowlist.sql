revoke select on table public.profiles from anon, authenticated;
grant select (
  id,
  display_name,
  handle,
  bio,
  avatar_path,
  created_at,
  updated_at
) on table public.profiles to authenticated;;
