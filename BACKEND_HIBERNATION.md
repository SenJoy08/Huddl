# Huddl Backend Hibernation Plan

## Current state

Huddl's frontend is considered the stable UI baseline. The Supabase layer is intentionally parked in `supabase/` and is not imported or executed by the current app.

## Implementation order later

1. Supabase project + Auth
2. Profile + onboarding persistence
3. Sports/profile skills
4. Generalized events + subtype records
5. Event membership + requests
6. Friends
7. Ratings + attendance
8. Notifications
9. Realtime event chat
10. Storage/avatars
11. RLS hardening and mobile QA

## Architectural rule

Do not turn `events` into a sports-only table. Sports, esports, gatherings, and future categories must continue to use the same generic event record and shared infrastructure.
