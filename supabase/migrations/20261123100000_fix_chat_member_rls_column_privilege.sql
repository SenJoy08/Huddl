
-- Fix chat membership RLS under event column-level SELECT restrictions.
-- Preserve existing membership visibility without directly querying
-- public.events from the authenticated user's RLS policy.

create or replace function private.is_event_host_member(
  target_event uuid,
  target_user uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.events e
    where e.id = target_event
      and e.host_id = target_user
  );
$function$;

-- SECURITY DEFINER is necessary because authenticated users intentionally
-- do not have unrestricted SELECT access to public.events.
revoke all on function private.is_event_host_member(uuid, uuid)
  from public, anon;

grant usage on schema private to authenticated;

grant execute on function private.is_event_host(uuid)
  to authenticated;

grant execute on function private.is_event_member(uuid)
  to authenticated;

grant execute on function private.is_public_event(uuid)
  to authenticated;

grant execute on function private.is_event_host_member(uuid, uuid)
  to authenticated;

-- Replace the policy that directly queried public.events.host_id.
drop policy if exists event_members_select on public.event_members;

create policy event_members_select
on public.event_members
for select
to authenticated
using (
  user_id = (select auth.uid())
  or private.is_event_host(event_id)
  or private.is_event_member(event_id)
  or private.is_public_event(event_id)
  or private.is_event_host_member(event_id, user_id)
);
