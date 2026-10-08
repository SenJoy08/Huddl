-- Prevent future public-schema objects from becoming API-reachable merely
-- because PostgreSQL's default PUBLIC/role grants were applied.
alter default privileges for role postgres in schema public
  revoke select, insert, update, delete on tables from anon, authenticated, service_role;

alter default privileges for role postgres in schema public
  revoke usage, select on sequences from anon, authenticated, service_role;

alter default privileges for role postgres in schema public
  revoke execute on functions from public;

-- Internal functions in the private schema should be callable only by the
-- authenticated policies/functions that explicitly need them.
revoke execute on function private.get_public_player_stats_internal(uuid) from public;
revoke execute on function private.has_event_join_request(uuid) from public;
revoke execute on function private.is_discoverable_event(uuid) from public;
revoke execute on function private.is_event_host(uuid) from public;
revoke execute on function private.is_event_member(uuid) from public;
revoke execute on function private.is_public_event(uuid) from public;

-- Preserve the explicit grants required by the current app/RLS path.
grant execute on function private.get_public_player_stats_internal(uuid) to authenticated;
grant execute on function private.has_event_join_request(uuid) to authenticated;
grant execute on function private.is_discoverable_event(uuid) to authenticated;
grant execute on function private.is_event_host(uuid) to authenticated;
grant execute on function private.is_event_member(uuid) to authenticated;
grant execute on function private.is_public_event(uuid) to authenticated;
