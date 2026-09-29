# Backend architecture notes

This is the backend contract to keep dormant until implementation begins.

## Generalization rule

`events` is intentionally generic. The category-specific fields are kept in subtype tables so adding esports, gatherings, or future categories does not turn the base table into a collection of nullable sport-specific columns.

## Join and friendship operations

The migration intentionally does **not** expose unrestricted browser-side inserts for event membership or friendships. When implementation begins, those operations should be transactional database functions (RPCs) that enforce business rules atomically, such as capacity, event status, visibility, duplicate requests, and friend-request state transitions.

## Rating semantics

`ratings.score` is nullable. A no-show is represented as `showed_up = false` and requires `score IS NULL` and `skill_match IS NULL`. A present player can receive a 1–5 score.

## Realtime

Event messages are persisted in `event_messages`. When chat is implemented, prefer Supabase Realtime Broadcast/private channels for the live transport and keep the database table as the durable message history. Supabase currently documents Broadcast as the recommended Realtime path for scalability/security. citeturn257578search11turn257578search3

## Auth

`profiles.id` references `auth.users(id)` and the signup trigger creates a matching profile. Supabase documents this public-profile pattern and warns that trigger failures can block signups, so the trigger is deliberately small and does not attempt to generate a unique handle automatically. citeturn257578search2

## Security baseline

All public-schema tables are covered by RLS, and unauthenticated `anon` access is revoked in the migration. Supabase's current RLS guidance recommends enabling RLS on exposed tables and managing grants separately from policies. citeturn257578search5turn257578search10
