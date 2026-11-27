
-- Keep SECURITY DEFINER RLS helpers out of the exposed public schema.
-- Supabase documents the private schema as an API-inaccessible place for
-- internal functions and tables.

create schema if not exists private;

revoke all on schema private from public;
revoke all on schema private from anon;
revoke all on schema private from authenticated;

-- RLS policies execute these helpers as the signed-in role. The helper
-- functions themselves are SECURITY DEFINER, so they can inspect the
-- protected rows without triggering recursive RLS. The private schema is
-- not exposed through the Data API.
grant usage on schema private to authenticated;

create or replace function private.has_event_join_request(target_event uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.event_join_requests r
    where r.event_id = target_event
      and r.user_id = auth.uid()
  );
$function$;

create or replace function private.is_discoverable_event(target_event uuid)
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
      and e.visibility in ('public', 'private')
      and e.status not in ('completed', 'cancelled')
  );
$function$;

create or replace function private.is_event_host(target_event uuid)
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
      and e.host_id = auth.uid()
  );
$function$;

create or replace function private.is_event_member(target_event uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.event_members em
    where em.event_id = target_event
      and em.user_id = auth.uid()
  );
$function$;

create or replace function private.is_public_event(target_event uuid)
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
      and e.visibility = 'public'
  );
$function$;

grant execute on function private.has_event_join_request(uuid) to authenticated;
grant execute on function private.is_discoverable_event(uuid) to authenticated;
grant execute on function private.is_event_host(uuid) to authenticated;
grant execute on function private.is_event_member(uuid) to authenticated;
grant execute on function private.is_public_event(uuid) to authenticated;

-- Rebind every RLS policy that used the public helpers.

drop policy if exists event_join_requests_select on public.event_join_requests;
create policy event_join_requests_select
on public.event_join_requests
for select
to authenticated
using (
  user_id = auth.uid()
  or private.is_event_host(event_id)
);

drop policy if exists event_join_requests_update_self_or_host on public.event_join_requests;
create policy event_join_requests_update_self_or_host
on public.event_join_requests
for update
to authenticated
using (
  user_id = auth.uid()
  or private.is_event_host(event_id)
)
with check (
  user_id = auth.uid()
  or private.is_event_host(event_id)
);

drop policy if exists event_members_delete_self_or_host on public.event_members;
create policy event_members_delete_self_or_host
on public.event_members
for delete
to authenticated
using (
  user_id = auth.uid()
  or private.is_event_host(event_id)
);

drop policy if exists event_members_insert_host on public.event_members;
create policy event_members_insert_host
on public.event_members
for insert
to authenticated
with check (
  private.is_event_host(event_id)
);

drop policy if exists event_members_select on public.event_members;
create policy event_members_select
on public.event_members
for select
to authenticated
using (
  user_id = auth.uid()
  or private.is_event_host(event_id)
  or private.is_event_member(event_id)
  or private.is_public_event(event_id)
  or user_id = (
    select e.host_id
    from public.events e
    where e.id = event_members.event_id
  )
);

drop policy if exists event_members_update_host on public.event_members;
create policy event_members_update_host
on public.event_members
for update
to authenticated
using (
  private.is_event_host(event_id)
)
with check (
  private.is_event_host(event_id)
);

drop policy if exists event_sports_select on public.event_sports;
create policy event_sports_select
on public.event_sports
for select
to authenticated
using (
  private.is_discoverable_event(event_id)
  or private.is_event_host(event_id)
  or private.is_event_member(event_id)
  or private.has_event_join_request(event_id)
);

drop policy if exists event_sports_write on public.event_sports;
create policy event_sports_write
on public.event_sports
for all
to authenticated
using (
  private.is_event_host(event_id)
)
with check (
  private.is_event_host(event_id)
);

drop policy if exists events_select_discoverable on public.events;
create policy events_select_discoverable
on public.events
for select
to authenticated
using (
  (
    visibility in ('public', 'private')
    and status not in ('completed', 'cancelled')
  )
  or host_id = auth.uid()
  or private.is_event_member(id)
  or private.has_event_join_request(id)
);

-- The helper functions are internal policy implementation details; remove
-- their public-schema API endpoints now that every policy uses private.*.
drop function if exists public.has_event_join_request(uuid);
drop function if exists public.is_discoverable_event(uuid);
drop function if exists public.is_event_host(uuid);
drop function if exists public.is_event_member(uuid);
drop function if exists public.is_public_event(uuid);
;
