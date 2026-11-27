# Huddl Supabase Backend

The Supabase backend is now live and is the production data source for the Svelte 5 frontend.

## Current architecture

`events` is the generic object. Event categories are data-driven through `event_types`:

- `sport`
- `esports`
- `gathering`
- `other`

Type-specific information lives in dedicated one-to-one tables:

- `event_sports`
- `event_esports`
- `event_gatherings`

Shared systems remain reusable across event types:

- membership
- join requests
- chat
- friends
- notifications
- ratings/attendance
- teams

The five skill levels are:

1. Beginner
2. Amateur
3. Intermediate
4. Seasoned
5. Professional

## Production hardening already applied

The live project currently has RLS enabled across the application tables, authenticated RPC permissions hardened, realtime enabled for the event/social tables, and public player statistics exposed through a dedicated RPC.

Private profile contact fields are not selectable by authenticated clients. The public `profiles` API exposes only the public profile columns, while the signed-in user's phone/contact-visibility settings are read through a locked RPC backed by a private `SECURITY DEFINER` helper.

The public player statistics RPC includes both regular sports and esports activity.

## Migration note

The live Supabase project contains additional migration history from the earlier backend implementation than is present in this archive. The live database is currently authoritative. Before the production deployment is treated as reproducible from a clean checkout, the remaining historical migrations should be pulled/reconciled into `supabase/migrations/` using the Supabase CLI.

Do not hand-edit the live migration history. New schema changes should be added as normal forward migrations.

The file `20261009041000_final_access_guardrails.sql` is a candidate forward migration from the final code audit. It has **not** been applied to the production database or tested against a staging copy in this delivery. It intentionally changes client table-write permissions and routes membership, lifecycle, and rating writes through guarded RPCs. Review it against the live schema, apply it in staging, and test the full join/leave/request/complete/rating flows before applying to production.

V2 adds `20261018090000_private_event_preview_and_access.sql`. It protects event details with column grants and member-aware RPCs, makes event edits transactional, routes friend writes through checked functions, and makes event messages append-only for clients. The migration depends on the existing historical schema and the `host_rated_at` guardrail. Reconcile the archived migration history, apply the existing guardrail prerequisites in staging, then apply this migration and verify the app against that staging database before production rollout. The new RPC names and parameters are implemented in the V2 client; deploying the client without the migration will make event discovery and edits fail.
