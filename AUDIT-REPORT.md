# Huddl Code Audit & Release Readiness Report

Audit date: 2026-10-09

## Scope

This pass reviewed the available Huddl source snapshot under `src/`, package/configuration files, Supabase migration files, project README, and known live Supabase function definitions. It made targeted fixes rather than broad stylistic rewrites.

This was a static source review. A full SvelteKit type check, production build, end-to-end browser/mobile test, and application of the proposed database migration to a staging database were **not completed** in this environment. Do not treat this report as a certification that every live flow works.

## Fixes made in this pass

### Event creation, discovery, and lifecycle

- Corrected the `Today` filter so it compares the event's local calendar date rather than comparing a noon timestamp to midnight.
- Excluded legacy `upcoming`/`full` events whose start timestamp is already in the past from discovery.
- Added strict date/time validation before the create/update event operations, including invalid calendar dates and past times.
- Routed cancellation through an explicit `cancel_event` RPC instead of direct status mutation.
- Fixed the finish-event flow so the post-game rating sheet receives the completed event state, rather than the stale pre-completion object.
- Made the host's completion action record the host as present through the proposed database guardrails.
- Improved the host's join-request feedback when capacity is reached during acceptance.
- Hid member leave and host edit controls after an event's start time, while retaining the post-game completion flow for the host.

### Realtime chat and async UI state

- Changed chat history loading to fetch the newest 200 messages and display them chronologically (rather than fetching the oldest 200).
- Scoped realtime chat subscriptions to the active event.
- Added session/version checks around chat, player-profile, and rating-player loads to prevent late responses from overwriting a newer screen state.
- Ensured chat subscriptions and polling are closed when chat is dismissed or navigation changes.
- Added a polling overlap guard so slow chat refresh requests cannot stack up.
- Hardened sign-in and password-reset submission state with `try/catch/finally` so controls do not remain stuck in a loading state after thrown errors.
- Made notification bulk-read logic fail clearly if there is no valid authenticated session.

### Profile and friends data

- Changed profile-sport saving to write new selections before deleting obsolete selections, reducing the chance of losing all sport associations if a write fails.
- Added support for clearing all sports without making an empty PostgREST `in` filter request.
- Kept the 250-person cap for discovery results but separately loads exact profiles referenced by existing friendships/requests so those people do not disappear beyond the discovery cap.
- Limits profile-sport association reads to profiles displayed in the current friends view, rather than reading every profile-sport row.

### UI and accessibility polish

- Added keyboard-visible focus styling with an explicit focus ring.
- Reduced unnecessary tap highlight effects on touch devices.
- Respects `prefers-reduced-motion` for button transitions.
- Preserved the app's existing pastel palette, mobile safe-area spacing, and footer attribution.

## Database migration included with this version

`supabase/migrations/20261009041000_final_access_guardrails.sql` is a **forward-only candidate migration for the existing Huddl database**, not a migration that has been applied or verified here. It covers:

- host-checked completion/cancellation and rating-completion RPCs;
- capacity-safe public joining and private join-request decisions;
- preventing participants from directly inserting/updating/deleting membership, join-request, or rating rows outside guarded RPC flows;
- host-only attendance marking, participant star-only ratings, completed-event validation, and rating note length limits;
- preventing active events from being left in inconsistent capacity states and preventing capacity from dropping below the current participant count;
- prevention of direct event deletion through the public client API.

**Before applying this migration:** review it against the actual production schema, back up the database, apply it in a staging project, run the multi-account tests below, then apply it through the agreed migration process. In particular, verify host event creation, public joining, private-request acceptance, leaving before start, event cancellation/completion, and host/member rating flows. The migration intentionally revokes direct table writes and expects these flows to use the named RPCs.

## Verification results

- JavaScript syntax: 15 `.js` files checked; zero syntax errors.
- Svelte embedded scripts: 11 script blocks across 12 `.svelte` files checked by extracting their JavaScript and running `node --check`; zero syntax errors.
- Local import resolution: 38 relative/`$lib` imports checked; zero unresolved local imports.
- Secret scan of the exported project source: no concrete secret key/token patterns found; `.env.example` was the only environment-style file present. This is not a substitute for scanning the full Git commit history.
- `npm run check`: **not passed / unable to run** because `svelte-kit` was not installed in the partial local `node_modules` directory.
- `npm run build`: **not passed / unable to run** because `vite` was not installed in the partial local `node_modules` directory.
- Dependency installation was previously blocked by registry DNS/network errors (`EAI_AGAIN`). Run `npm ci`, `npm run check`, and `npm run build` on the development machine before merging this version.
- No live migration was applied, and no production database mutation was made as part of this audit.

## Remaining operational checks

1. On a machine with package registry access, run `npm ci`, `npm run check`, and `npm run build` and resolve any Svelte diagnostics revealed by the complete compiler.
2. Reconcile the repository's historical Supabase migrations with the production migration history. `supabase/README.md` explains that the current project has schema history not fully represented in this archive, so a clean empty-database bootstrap is not yet proven reproducible.
3. Apply the candidate guardrail migration to a staging database and verify the core flows with at least two accounts.
4. Review the Supabase Auth leaked-password protection setting; it was previously identified as a remaining hardening item, depending on the project's plan/settings.
5. Run authenticated preview deployment smoke tests on desktop and mobile, including account creation, password reset, profiles/privacy, event filters, game creation, join/request/decision, chat, notifications, stats, attendance and ratings.
6. Scan the complete Git history for accidentally committed secrets before making the repository public. If any real key or token was exposed, rotate it even if it is removed from the latest tree.

## Known scale limits

- Friend/person discovery is intentionally capped at 250 candidates per load; existing relationship profiles are loaded separately.
- Chat loads the newest 200 messages per event. Message pagination for very long-running events is not implemented.
- Event discovery currently uses a bounded list rather than full pagination; add cursor/page-based loading if production volume grows.

