# Huddl Backend — Hibernating Foundation

This directory is deliberately **not connected to the Svelte frontend yet**.

The purpose is to freeze the backend architecture now so that later implementation can be done against a stable, scalable model without redesigning the app around sports-only assumptions.

## Core model

`events` is the generic object. Event categories are data-driven through `event_types`:

- `sport`
- `esports`
- `gathering`
- `other`

Type-specific information lives in dedicated one-to-one tables:

- `event_sports`
- `event_esports`
- `event_gatherings`

Shared systems remain reusable across all event types:

- membership
- join requests
- chat
- friends
- notifications
- ratings/attendance
- teams

## Future expansion

Adding another sport or esports game is intended to be a data change, not a schema rewrite. A new event category can be introduced by adding a new `event_types` row and, when it needs unique fields, one new subtype table.

Teams are already represented generically so esports can later support team formation without replacing the event membership model.

Ratings intentionally allow `score = NULL` when `showed_up = false`, matching Huddl's current no-show behavior.

The five skill levels are seeded as:

1. Beginner
2. Amateur
3. Intermediate
4. Seasoned
5. Professional

## Included sport seed data

Football, Volleyball, Tennis, Basketball, Badminton, Chess, Pool, Table Tennis, Cricket, Futsal, Squash, Box Cricket.

## What is intentionally *not* happening yet

- No Supabase project is connected.
- No runtime Supabase client is added to Huddl.
- No existing mock/local frontend behavior is replaced.
- No production credentials or environment variables are required.

When backend implementation begins, the migration can be applied first, followed by replacing the current local session/data services feature-by-feature.
