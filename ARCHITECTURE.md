# Huddl V2.0 application structure

Huddl uses SvelteKit's filesystem routing. Files under `src/routes` define URLs; reusable interface pieces belong in `src/lib/components`; data access and feature rules belong in `src/lib/data`; authentication/session helpers belong in `src/lib/auth`; global setup belongs in `src/lib/supabase`.

## Current map

```text
src/
  routes/
    +layout.svelte          Shared document metadata and route slot
    +page.svelte            Authenticated app shell and screen orchestration
    +error.svelte           App-wide route error UI
    login/                  Sign-in and sign-up routes
    onboarding/             New-user setup
    auth/callback/           Supabase auth callback
    auth/reset-password/     Password recovery
  lib/
    components/             AuthShell, BottomNav, EventCard, event detail pieces, Icon
    data/                   Feature data operations (events, friends, chat, profile, etc.)
    auth/                   Session lifecycle
    supabase/                Browser client configuration
```

## SvelteKit conventions for new work

- A route folder owns a screen or URL. `+page.svelte` renders the page; `+page.js` or `+page.server.js` loads route data; `+layout.svelte` wraps child routes; `+error.svelte` handles route errors; `+server.js` is for HTTP endpoints.
- Keep `+page.svelte` focused on screen composition and state coordination. Move repeated or independently understandable UI into small components with explicit props and events. Keep database operations out of visual components.
- Keep each feature's queries and mutations in `src/lib/data/<feature>.js`. Centralize auth and Supabase client setup rather than creating clients inside page components.
- Use route `load` functions for data needed to render a URL, and actions/endpoints for server-only work. Browser-side Supabase calls are appropriate for this app's authenticated interactive flows only when RLS and grants enforce the same authorization.
- Prefer one transactional database function for changes spanning multiple tables. Validate authorization and business rules in that transaction; make the UI refresh from the resulting persisted state.
- Share design tokens and global CSS through `src/routes/+layout.svelte` or a global stylesheet. Keep component-only styles in the component.
- Use descriptive filenames, one responsibility per component/module, and JSDoc types while this project remains JavaScript. Adopt TypeScript incrementally when it reduces ambiguity rather than changing the whole codebase during a polish pass.

The V2 page still coordinates several screens in one route. New screens should be extracted as work touches them, preserving the current presentation. Event card/detail metadata and attendee display have already been separated into reusable components.
