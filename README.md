# Huddl

**Built and maintained by Sanjay Shashibushan**

Huddl is a mobile-first platform for finding people to play sports and esports with. Users can discover games, host public or private events, join or request access to games, connect with friends, chat with event participants, and build a player profile from participation and ratings.

Repository: [SenJoy08/Huddl](https://github.com/SenJoy08/Huddl)

---

## Contents

- [What Huddl does](#what-huddl-does)
- [Feature overview](#feature-overview)
- [Technology stack](#technology-stack)
- [Project layout](#project-layout)
- [Getting started](#getting-started)
- [Environment variables](#environment-variables)
- [Database and Supabase](#database-and-supabase)
- [Security and privacy](#security-and-privacy)
- [Development commands](#development-commands)
- [Deployment](#deployment)
- [Contributing and update workflow](#contributing-and-update-workflow)
- [Testing and release checklist](#testing-and-release-checklist)
- [Current limitations and operational notes](#current-limitations-and-operational-notes)

## What Huddl does

Huddl helps people organize pickup games and find players at a suitable skill level. It brings event discovery, player connections, event coordination, and post-game ratings into one application. The event catalog supports conventional sports as well as esports, with game catalog data loaded from Supabase.

## Feature overview

### Accounts and onboarding

- Sign up and log in with Supabase Authentication.
- Guided onboarding and profile setup.
- Sign out through the Supabase authentication session.
- Password-reset flow, including a recovery route for setting a new password.
- Duplicate-submit guards during asynchronous account creation and onboarding.
- User-facing errors for common authentication, network, permission, and unavailable-game failures.

### Player profiles and stats

- Player profile with display name, handle, bio, sports, skill information, and a generated pastel initial/avatar color.
- Open a player's profile from their name or avatar throughout the interface.
- Public player statistics, including games played, games hosted, rating and rating count, attendance, and sport/game activity where available.
- Profile contact visibility is designed to respect privacy preferences and friendship relationships.
- Profile photo upload is not currently a core feature; the interface uses initials and color styling instead.

### Sports and esports

- Browse sports and esports from the same discovery experience.
- The current sports catalog includes volleyball, tennis, basketball, badminton, chess, pool, table tennis, cricket, futsal, squash, and box cricket. The catalog is database-driven and may change as catalog records are updated.
- Esports games are loaded from the esports catalog and can be filtered by individual game.
- Event skill levels: **Beginner**, **Amateur**, **Intermediate**, **Seasoned**, and **Professional**.

### Event creation and discovery

- Create an event with a title, description, date, time, location, capacity, visibility, sport/game, and skill level.
- Public and private events.
- Browse upcoming events and see whether they are open or full.
- Search events and filter by sport/esport, game, time, availability, and skill level.
- Clear filters to return to the full discovery view.
- Event status and membership information are reflected in event cards.
- Resilient event refresh and hydration: secondary lookup failures should not discard otherwise usable event information.

### Joining and hosting games

- Join public games when eligible and space is available.
- Request to join private games; the host can review requests and make a decision.
- Private events remain discoverable/requestable, while details are restricted to the host, members, and users with a pending join request according to database policies.
- Hosts appear as participants in their own events.
- Event membership, capacity, and join-request state are coordinated through Supabase data operations/RPCs.
- Past, completed, or cancelled events cannot be joined or requested through the enforced time-boundary checks.

### Friends and notifications

- Friend discovery and friend-request workflows.
- View and refresh the friends list.
- Notifications for supported activity, with realtime updates where configured.
- Marking a notification as read removes it from the active notification list.
- Loading failures have user-facing retry states where implemented.

### Event chat and realtime updates

- Group chat associated with a game/event.
- Chat is intended for event participants and is disabled when the event is completed.
- Send controls are disabled while a message is empty or being sent.
- Realtime subscriptions support event, membership, join-request, message, notification, friendship, and friend-request changes, according to the active Supabase Realtime publication/configuration.
- The app refreshes key data when the page regains focus or becomes visible.

### Ratings and attendance

- Players can rate other participants using a star rating after a game.
- Only the event creator/host can record whether a player showed up; other participants can submit star ratings but do not control attendance status.
- Rating controls are hidden after the relevant rating flow has been completed for an event.
- Public statistics include rating count and aggregate rating where data is available.

### Interface and resilience

- Mobile-first interface with bottom navigation for primary areas such as Home, Friends, Stats, and Profile.
- Pastel avatar colors and a consistent visual style.
- Mobile safe-area spacing for fixed navigation and floating controls.
- Retryable error states for events, friends, stats, notifications, chat, player profiles, and rating-player loading where implemented.
- A global SvelteKit error page at `src/routes/+error.svelte`.
- Footer attribution: “built and maintained by Sanjay Shashibushan”.

## Technology stack

| Area | Technology |
|---|---|
| UI framework | Svelte 5 |
| Application framework / routing | SvelteKit 2 |
| Development server and bundler | Vite 6 |
| Language and diagnostics | JavaScript with JSDoc types, `svelte-check`, TypeScript tooling |
| Authentication and database | Supabase Auth and PostgreSQL |
| Browser data client | `@supabase/supabase-js` |
| SSR-compatible Supabase helpers | `@supabase/ssr` |
| Hosting / CI deployment | Vercel |
| Source control | Git and GitHub |

Exact dependency ranges are maintained in `package.json` and `package-lock.json`.

## Project layout

The main application areas include:

```text
.
├── src/
│   ├── lib/
│   │   ├── auth/             # Session helpers and auth-related flows
│   │   ├── components/       # Shared UI, including event cards and bottom navigation
│   │   ├── data/             # Supabase-backed data access for events, chat, friends,
│   │   │                     # notifications, profiles, ratings, realtime, stats, esports
│   │   └── supabase/         # Supabase client/configuration
│   └── routes/
│       ├── +page.svelte      # Main Huddl application interface
│       ├── +error.svelte     # Application-level error fallback
│       ├── login/            # Login route
│       ├── signup/           # Account registration route
│       ├── onboarding/       # Initial profile setup
│       ├── reset-password/   # Password recovery/update route
│       └── ...               # Auth callback and additional route handlers
├── supabase/
│   └── migrations/           # SQL migrations for database schema, RPCs, RLS, and indexes
├── .env.example              # Variable-name template; create local .env from it
├── .gitignore
├── package.json
├── package-lock.json
└── README.md
```

The exact tree may evolve. Keep database access logic in `src/lib/data/` rather than duplicating Supabase queries inside UI components when adding new functionality.

## Getting started

### Prerequisites

- Node.js and npm. Use a current supported Node.js LTS release, and keep the local Node version aligned with the version configured for the Vercel project where practical.
- Git.
- Access to the Huddl Supabase project or another configured Supabase project.
- The repository cloned locally.

### 1. Clone the repository

```bash
git clone https://github.com/SenJoy08/Huddl.git
cd Huddl
```

If the repository is already cloned, navigate to the project root instead.

### 2. Install dependencies

```bash
npm ci
```

Use `npm ci` when a lockfile is present so dependency installation follows `package-lock.json`.

### 3. Configure the environment

Copy `.env.example` to `.env` and fill in the values for your Supabase project. On Windows Command Prompt:

```bat
copy .env.example .env
```

On PowerShell:

```powershell
Copy-Item .env.example .env
```

See [Environment variables](#environment-variables) below.

### 4. Start the development server

```bash
npm run dev
```

Open the local URL printed by Vite in the terminal (normally `http://localhost:5173`). Stop the server with `Ctrl+C`.

### 5. Check and build

Before committing changes, run:

```bash
npm run check
npm run build
```

To run the production build locally:

```bash
npm run preview
```

The preview command serves the build output; it does not replace a deployment.

## Environment variables

Huddl expects these public client configuration values:

| Variable | Purpose |
|---|---|
| `PUBLIC_SUPABASE_URL` | URL of the Supabase project used by the app |
| `PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Supabase publishable key used by the browser client |

Example `.env.example`:

```dotenv
PUBLIC_SUPABASE_URL=https://your-project-ref.supabase.co
PUBLIC_SUPABASE_PUBLISHABLE_KEY=your-supabase-publishable-key
```

The values above are placeholders. Use the values for the intended environment.

**Never commit `.env` or other files containing credentials.** The `.gitignore` should exclude `.env`, `.env.*`, `node_modules/`, `.svelte-kit/`, and `.vercel/`, while explicitly allowing `.env.example`. Supabase publishable keys are designed for frontend use, but access control must be enforced with Row Level Security (RLS). Never put a Supabase `service_role`/secret key into a `PUBLIC_` variable, browser code, or GitHub.

In Vercel, configure `PUBLIC_SUPABASE_URL` and `PUBLIC_SUPABASE_PUBLISHABLE_KEY` under the project's Environment Variables for the environments you deploy (Production and Preview as applicable). Redeploy after changing environment variables.

## Database and Supabase

Huddl uses Supabase for authentication, persistent application data, database-side validation, and realtime events. Database migrations are kept under `supabase/migrations/`.

### Main data areas

The data layer covers:

- User profiles and profile/contact visibility.
- Sports, skill levels, and esports game catalog.
- Events, membership, capacity, and join requests.
- Friendships and friend requests.
- Event chat messages.
- Notifications.
- Ratings and attendance.
- Public player statistics.

Some security-sensitive actions use Postgres functions/RPCs (for example, joining an event and requesting to join a private event) so important checks are enforced at the database boundary as well as in the UI.

### Row Level Security and privacy

The production data model relies on Supabase Row Level Security. The intended rules include:

- Public profile reads are limited to an allowlist of non-private fields.
- Contact details are returned according to profile privacy preferences and the viewer's relationship to the player; clients should use the approved data/RPC path rather than querying private columns directly.
- Event visibility distinguishes public discovery from access to private-event details.
- Only permitted users can see member-only event data, join requests, chats, ratings, and other user-specific records.
- Event join and private-join-request functions enforce event status and start-time boundaries.

Do not disable RLS to make a feature work. Correct the relevant policy, grant, or RPC and test with more than one authenticated account.

### Applying database changes

1. Review the migration files and their order before applying them.
2. Ensure the Supabase CLI is installed and linked to the intended project if you plan to use CLI migration commands.
3. Back up production data and inspect the recorded migration history before applying migrations to a live project.
4. Apply and verify changes in a development/staging project first when possible.
5. Recheck RLS, grants, RPC execute permissions, Realtime publication membership, and relevant application flows after changes.

Do not blindly replay SQL migrations against a production database. The database may already contain migrations that were applied directly or through a separate workflow.

## Development commands

| Command | Purpose |
|---|---|
| `npm run dev` | Start the Vite/SvelteKit development server |
| `npm run check` | Synchronize SvelteKit and run Svelte/JavaScript diagnostics |
| `npm run build` | Create a production build |
| `npm run preview` | Preview the built app locally |
| `npm ci` | Install exact locked dependencies |

## Deployment

Huddl is deployed with Vercel and connected to the GitHub repository. The intended production flow is to deploy from `main`.

### Vercel configuration

- Framework preset: SvelteKit.
- Install command: `npm ci`.
- Build command: `npm run build`.
- Configure `PUBLIC_SUPABASE_URL` and `PUBLIC_SUPABASE_PUBLISHABLE_KEY` in Vercel Environment Variables.
- Check **Project → Deployments** for build logs and deployment status.
- Check **Project → Settings → Domains** for the exact assigned production URL and domain status.
- Keep deployment protection enabled where it is useful; a protected deployment may require authentication to open.

### Deploying a normal code change

After editing and testing the code:

```bash
git status
git add .
git commit -m "Describe the change"
git push
```

Pushing to `main` triggers a new deployment when the Git integration is configured for that branch. Wait for the build to finish and inspect the deployment result before relying on the change in production. Branches other than the configured production branch can be used for preview deployments when Vercel Git settings allow it.

### Deployment troubleshooting

- **Build failure:** open the deployment's build logs and reproduce locally with `npm ci`, `npm run check`, and `npm run build`.
- **Missing Supabase configuration:** verify both public environment variables exist in the relevant Vercel environment, then redeploy.
- **App loads but data is missing:** check the browser console, Supabase logs, RLS policies, grants, RPC permissions, and whether migrations/catalog records are present.
- **Domain invalid:** follow the exact DNS record and verification instructions shown in Vercel for the domain you control. A custom domain must be registered/controlled by you; Vercel's default project hostname normally uses `vercel.app`.

## Contributing and update workflow

1. Start from an up-to-date `main` branch:
   ```bash
   git checkout main
   git pull
   ```
2. Create a branch for a larger change if a preview is needed:
   ```bash
   git checkout -b fix/short-description
   ```
3. Make the smallest focused change possible.
4. Run `npm run check` and `npm run build`.
5. Review `git diff` and confirm no environment files or secrets are included.
6. Commit and push:
   ```bash
   git add .
   git commit -m "Describe the change"
   git push -u origin HEAD
   ```
7. Test the Vercel preview (if applicable), then merge the change into `main` to release it.

Keep commits descriptive. Do not commit generated output or local state such as `node_modules/`, `.svelte-kit/`, `.vercel/`, or `.env`.

## Testing and release checklist

Before releasing a change, test the flows affected by it. For a broad release, use this checklist:

- [ ] `npm ci` succeeds.
- [ ] `npm run check` passes with no diagnostics.
- [ ] `npm run build` succeeds.
- [ ] Signup, login, onboarding, logout, and password reset work.
- [ ] Profile details and privacy behavior are correct under separate accounts.
- [ ] Event creation, public join, private join request, host decision, capacity limits, and past-event boundaries behave correctly.
- [ ] Sports and esports discovery, search, and filters work.
- [ ] Friends, notifications, event chat, and realtime updates work with two authenticated users.
- [ ] Only the event host can mark attendance; star ratings behave as intended.
- [ ] RLS and RPC grants have been tested and not bypassed.
- [ ] Production environment variables are present and no secrets are committed.
- [ ] Vercel build logs are clean and the deployed app has been smoke-tested on desktop and mobile.

## Current limitations and operational notes

- The exact list of sports and esports is database/catalog-driven. Update catalog data and related validation together when adding new categories.
- Profile photo upload is not currently a core feature; player identities use initials and generated pastel colors.
- The Supabase security review previously identified leaked-password protection as a remaining hardening item. Review Supabase Auth's password-security settings before broad public launch, depending on plan availability.
- Performance tooling previously reported unused-index suggestions. Keep indexes until actual query patterns and production traffic have been assessed; do not remove indexes solely because an advisor labels them unused in a low-traffic environment.
- This README describes the current project direction and implemented feature set; confirm behavior in the current source and live deployment when changing database policies or release settings.

---

© Huddl — built and maintained by Sanjay Shashibushan.
