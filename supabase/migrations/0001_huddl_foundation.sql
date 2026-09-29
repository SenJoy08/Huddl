-- Huddl backend foundation
-- HIBERNATING / NOT CONNECTED TO THE FRONTEND YET.
-- Apply later through Supabase migrations when backend implementation begins.

create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- Generic lookup tables
-- -----------------------------------------------------------------------------

create table if not exists public.event_types (
  code text primary key,
  name text not null,
  description text,
  enabled boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.sports (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null unique,
  enabled boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.skill_levels (
  code text primary key,
  name text not null unique,
  sort_order smallint not null unique check (sort_order > 0),
  description text,
  created_at timestamptz not null default now()
);

create table if not exists public.esports_games (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null unique,
  platform text,
  enabled boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.gathering_types (
  code text primary key,
  name text not null unique,
  description text,
  enabled boolean not null default true,
  created_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- Profiles / preferences
-- -----------------------------------------------------------------------------

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  handle text unique,
  bio text,
  phone text,
  contact_visibility text not null default 'friends'
    check (contact_visibility in ('nobody', 'friends', 'everyone')),
  avatar_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.notification_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  event_updates boolean not null default true,
  friend_updates boolean not null default true,
  rating_reminders boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.profile_sports (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  sport_id uuid not null references public.sports(id) on delete restrict,
  skill_level_code text not null references public.skill_levels(code) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (profile_id, sport_id)
);

create index if not exists profile_sports_sport_idx on public.profile_sports(sport_id);

-- -----------------------------------------------------------------------------
-- Events: one generalized object, specialized by subtype tables
-- -----------------------------------------------------------------------------

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  event_type_code text not null references public.event_types(code) on delete restrict,
  host_id uuid not null references public.profiles(id) on delete restrict,
  title text not null,
  description text,
  starts_at timestamptz not null,
  location_name text,
  location_lat double precision,
  location_lng double precision,
  capacity integer not null check (capacity >= 2 and capacity <= 1000),
  visibility text not null default 'public'
    check (visibility in ('public', 'private')),
  status text not null default 'upcoming'
    check (status in ('upcoming', 'full', 'completed', 'cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists events_type_idx on public.events(event_type_code);
create index if not exists events_host_idx on public.events(host_id);
create index if not exists events_starts_at_idx on public.events(starts_at);
create index if not exists events_status_visibility_idx on public.events(status, visibility);

create table if not exists public.event_sports (
  event_id uuid primary key references public.events(id) on delete cascade,
  sport_id uuid not null references public.sports(id) on delete restrict,
  skill_level_code text not null references public.skill_levels(code) on delete restrict
);

create index if not exists event_sports_sport_idx on public.event_sports(sport_id);

create table if not exists public.event_esports (
  event_id uuid primary key references public.events(id) on delete cascade,
  game_id uuid not null references public.esports_games(id) on delete restrict,
  platform text,
  game_mode text,
  team_size integer check (team_size is null or team_size >= 1 and team_size <= 100)
);

create index if not exists event_esports_game_idx on public.event_esports(game_id);

create table if not exists public.event_gatherings (
  event_id uuid primary key references public.events(id) on delete cascade,
  gathering_type_code text references public.gathering_types(code) on delete restrict,
  dress_code text,
  age_note text
);

create table if not exists public.event_members (
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('host', 'member')),
  showed_up boolean,
  joined_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

create index if not exists event_members_user_idx on public.event_members(user_id);
create index if not exists event_members_event_role_idx on public.event_members(event_id, role);

create table if not exists public.event_join_requests (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'cancelled')),
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  unique (event_id, user_id)
);

create index if not exists event_join_requests_event_status_idx
  on public.event_join_requests(event_id, status);
create index if not exists event_join_requests_user_idx
  on public.event_join_requests(user_id);

-- -----------------------------------------------------------------------------
-- Optional generalized teams, ready for esports and team-based activities
-- -----------------------------------------------------------------------------

create table if not exists public.event_teams (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  name text not null,
  sort_order integer not null default 1 check (sort_order > 0),
  unique (event_id, name),
  unique (event_id, sort_order)
);

create table if not exists public.event_team_members (
  team_id uuid not null references public.event_teams(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (team_id, user_id)
);

create index if not exists event_team_members_user_idx on public.event_team_members(user_id);

-- -----------------------------------------------------------------------------
-- Friends
-- Canonical ordering keeps one row per friendship.
-- -----------------------------------------------------------------------------

create table if not exists public.friendships (
  user_a uuid not null references public.profiles(id) on delete cascade,
  user_b uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_a, user_b),
  check (user_a < user_b)
);

create index if not exists friendships_user_b_idx on public.friendships(user_b);

create table if not exists public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  receiver_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'cancelled')),
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  unique (sender_id, receiver_id)
);

create index if not exists friend_requests_receiver_status_idx
  on public.friend_requests(receiver_id, status);
create index if not exists friend_requests_sender_status_idx
  on public.friend_requests(sender_id, status);

-- -----------------------------------------------------------------------------
-- Ratings / attendance
-- A missing score is intentional for no-shows.
-- -----------------------------------------------------------------------------

create table if not exists public.ratings (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  rater_id uuid not null references public.profiles(id) on delete cascade,
  ratee_id uuid not null references public.profiles(id) on delete cascade,
  score smallint check (score is null or score between 1 and 5),
  showed_up boolean not null,
  skill_match boolean,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (event_id, rater_id, ratee_id),
  check (rater_id <> ratee_id),
  check (showed_up or (score is null and skill_match is null))
);

create index if not exists ratings_ratee_idx on public.ratings(ratee_id);
create index if not exists ratings_event_idx on public.ratings(event_id);
create index if not exists ratings_rater_idx on public.ratings(rater_id);

-- -----------------------------------------------------------------------------
-- Notifications
-- -----------------------------------------------------------------------------

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  type text not null,
  event_id uuid references public.events(id) on delete cascade,
  friend_request_id uuid references public.friend_requests(id) on delete cascade,
  message text not null,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists notifications_recipient_created_idx
  on public.notifications(recipient_id, created_at desc);
create index if not exists notifications_recipient_unread_idx
  on public.notifications(recipient_id, read) where read = false;

-- -----------------------------------------------------------------------------
-- Event chat
-- One conversation per event; the event itself is the room identifier.
-- -----------------------------------------------------------------------------

create table if not exists public.event_messages (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (length(btrim(body)) between 1 and 2000),
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz
);

create index if not exists event_messages_event_created_idx
  on public.event_messages(event_id, created_at);

-- -----------------------------------------------------------------------------
-- Shared helper functions for RLS and future server-side logic
-- -----------------------------------------------------------------------------

create or replace function public.is_event_member(target_event uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.event_members em
    where em.event_id = target_event
      and em.user_id = auth.uid()
  );
$$;

create or replace function public.is_event_host(target_event uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.events e
    where e.id = target_event
      and e.host_id = auth.uid()
  );
$$;

create or replace function public.are_friends(user_one uuid, user_two uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.friendships f
    where f.user_a = least(user_one, user_two)
      and f.user_b = greatest(user_one, user_two)
  );
$$;

-- -----------------------------------------------------------------------------
-- Timestamps and automatic profile creation
-- -----------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists notification_preferences_set_updated_at on public.notification_preferences;
create trigger notification_preferences_set_updated_at
before update on public.notification_preferences
for each row execute function public.set_updated_at();

drop trigger if exists events_set_updated_at on public.events;
create trigger events_set_updated_at
before update on public.events
for each row execute function public.set_updated_at();

drop trigger if exists ratings_set_updated_at on public.ratings;
create trigger ratings_set_updated_at
before update on public.ratings
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  display_name_value text;
begin
  display_name_value := coalesce(
    nullif(trim(new.raw_user_meta_data->>'display_name'), ''),
    split_part(coalesce(new.email, 'huddl-user'), '@', 1)
  );

  insert into public.profiles (id, display_name)
  values (new.id, display_name_value)
  on conflict (id) do nothing;

  insert into public.notification_preferences (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.add_event_host_as_member()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.event_members (event_id, user_id, role)
  values (new.id, new.host_id, 'host')
  on conflict (event_id, user_id) do update set role = 'host';
  return new;
end;
$$;

drop trigger if exists on_event_created_add_host on public.events;
create trigger on_event_created_add_host
after insert on public.events
for each row execute function public.add_event_host_as_member();

-- -----------------------------------------------------------------------------
-- Seed data (idempotent)
-- -----------------------------------------------------------------------------

insert into public.event_types (code, name, description) values
  ('sport', 'Sport', 'Traditional and recreational sports'),
  ('esports', 'Esports', 'Competitive video games and online games'),
  ('gathering', 'Gathering', 'Social meetups and group gatherings'),
  ('other', 'Other', 'Future event categories')
on conflict (code) do update set name = excluded.name, description = excluded.description;

insert into public.skill_levels (code, name, sort_order, description) values
  ('beginner', 'Beginner', 1, 'New to the sport'),
  ('amateur', 'Amateur', 2, 'Some experience and basic confidence'),
  ('intermediate', 'Intermediate', 3, 'Comfortable playing full games'),
  ('seasoned', 'Seasoned', 4, 'Strong, experienced player'),
  ('professional', 'Professional', 5, 'High-level competitive player')
on conflict (code) do update set
  name = excluded.name,
  sort_order = excluded.sort_order,
  description = excluded.description;

insert into public.sports (slug, name) values
  ('football', 'Football'),
  ('volleyball', 'Volleyball'),
  ('tennis', 'Tennis'),
  ('basketball', 'Basketball'),
  ('badminton', 'Badminton'),
  ('chess', 'Chess'),
  ('pool', 'Pool'),
  ('table-tennis', 'Table Tennis'),
  ('cricket', 'Cricket'),
  ('futsal', 'Futsal'),
  ('squash', 'Squash'),
  ('box-cricket', 'Box Cricket')
on conflict (slug) do update set name = excluded.name;

insert into public.gathering_types (code, name, description) values
  ('hangout', 'Hangout', 'Casual social meetup'),
  ('movie', 'Movie Night', 'Group movie or screening'),
  ('dinner', 'Dinner', 'Group meal'),
  ('study', 'Study Session', 'Group study meetup'),
  ('trip', 'Trip', 'Group outing or excursion'),
  ('other', 'Other', 'Other gathering')
on conflict (code) do update set name = excluded.name, description = excluded.description;

-- -----------------------------------------------------------------------------
-- API grants
-- RLS controls which rows are accessible; grants control which operations are
-- available to each Postgres role. Keep unauthenticated access off by default.
-- -----------------------------------------------------------------------------

revoke all on all tables in schema public from anon;
revoke all on all tables in schema public from authenticated;
revoke all on all sequences in schema public from anon;
revoke all on all sequences in schema public from authenticated;

grant usage on schema public to authenticated;

grant select on public.event_types, public.sports, public.skill_levels,
  public.esports_games, public.gathering_types to authenticated;

grant select, insert, update on public.profiles to authenticated;
grant select, insert, update, delete on public.profile_sports to authenticated;
grant select, insert, update, delete on public.notification_preferences to authenticated;

grant select, insert, update, delete on public.events to authenticated;
grant select, insert, update, delete on public.event_sports to authenticated;
grant select, insert, update, delete on public.event_esports to authenticated;
grant select, insert, update, delete on public.event_gatherings to authenticated;
grant select, insert, update, delete on public.event_members to authenticated;
grant select, insert, update on public.event_join_requests to authenticated;
grant select, insert, update, delete on public.event_teams to authenticated;
grant select, insert, delete on public.event_team_members to authenticated;
grant select, delete on public.friendships to authenticated;
grant select, insert on public.friend_requests to authenticated;
grant select, insert, update, delete on public.ratings to authenticated;
grant select, update on public.notifications to authenticated;
grant select, insert, update, delete on public.event_messages to authenticated;

-- -----------------------------------------------------------------------------
-- Row Level Security
-- -----------------------------------------------------------------------------

alter table public.event_types enable row level security;
alter table public.sports enable row level security;
alter table public.skill_levels enable row level security;
alter table public.esports_games enable row level security;
alter table public.gathering_types enable row level security;
alter table public.profiles enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.profile_sports enable row level security;
alter table public.events enable row level security;
alter table public.event_sports enable row level security;
alter table public.event_esports enable row level security;
alter table public.event_gatherings enable row level security;
alter table public.event_members enable row level security;
alter table public.event_join_requests enable row level security;
alter table public.event_teams enable row level security;
alter table public.event_team_members enable row level security;
alter table public.friendships enable row level security;
alter table public.friend_requests enable row level security;
alter table public.ratings enable row level security;
alter table public.notifications enable row level security;
alter table public.event_messages enable row level security;

-- Public authenticated lookups.
drop policy if exists event_types_select_authenticated on public.event_types;
create policy event_types_select_authenticated on public.event_types
for select to authenticated using (enabled = true);

drop policy if exists sports_select_authenticated on public.sports;
create policy sports_select_authenticated on public.sports
for select to authenticated using (enabled = true);

drop policy if exists skill_levels_select_authenticated on public.skill_levels;
create policy skill_levels_select_authenticated on public.skill_levels
for select to authenticated using (true);

drop policy if exists esports_games_select_authenticated on public.esports_games;
create policy esports_games_select_authenticated on public.esports_games
for select to authenticated using (enabled = true);

drop policy if exists gathering_types_select_authenticated on public.gathering_types;
create policy gathering_types_select_authenticated on public.gathering_types
for select to authenticated using (enabled = true);

-- Profiles: authenticated users may discover profiles; users manage their own row.
drop policy if exists profiles_select_authenticated on public.profiles;
create policy profiles_select_authenticated on public.profiles
for select to authenticated using (true);

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles
for insert to authenticated with check (id = auth.uid());

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- Profile sports: everyone authenticated can read; users write their own.
drop policy if exists profile_sports_select_authenticated on public.profile_sports;
create policy profile_sports_select_authenticated on public.profile_sports
for select to authenticated using (true);

drop policy if exists profile_sports_insert_own on public.profile_sports;
create policy profile_sports_insert_own on public.profile_sports
for insert to authenticated with check (profile_id = auth.uid());

drop policy if exists profile_sports_update_own on public.profile_sports;
create policy profile_sports_update_own on public.profile_sports
for update to authenticated using (profile_id = auth.uid()) with check (profile_id = auth.uid());

drop policy if exists profile_sports_delete_own on public.profile_sports;
create policy profile_sports_delete_own on public.profile_sports
for delete to authenticated using (profile_id = auth.uid());

-- Notification preferences: private to the owner.
drop policy if exists notification_preferences_own on public.notification_preferences;
create policy notification_preferences_own on public.notification_preferences
for all to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- Events: public upcoming events are discoverable; private events require membership/host/request visibility.
drop policy if exists events_select_discoverable on public.events;
create policy events_select_discoverable on public.events
for select to authenticated
using (
  visibility = 'public'
  or host_id = auth.uid()
  or public.is_event_member(id)
  or exists (
    select 1 from public.event_join_requests r
    where r.event_id = events.id and r.user_id = auth.uid()
  )
);

drop policy if exists events_insert_hosted on public.events;
create policy events_insert_hosted on public.events
for insert to authenticated
with check (host_id = auth.uid());

drop policy if exists events_update_host on public.events;
create policy events_update_host on public.events
for update to authenticated
using (host_id = auth.uid())
with check (host_id = auth.uid());

drop policy if exists events_delete_host on public.events;
create policy events_delete_host on public.events
for delete to authenticated using (host_id = auth.uid());

-- Event subtype data follows the same access rule as its event.
drop policy if exists event_sports_select on public.event_sports;
create policy event_sports_select on public.event_sports
for select to authenticated using (
  exists (select 1 from public.events e where e.id = event_id and (
    e.visibility = 'public' or e.host_id = auth.uid() or public.is_event_member(e.id)
  ))
);
drop policy if exists event_sports_write on public.event_sports;
create policy event_sports_write on public.event_sports
for all to authenticated
using (public.is_event_host(event_id))
with check (public.is_event_host(event_id));

drop policy if exists event_esports_select on public.event_esports;
create policy event_esports_select on public.event_esports
for select to authenticated using (
  exists (select 1 from public.events e where e.id = event_id and (
    e.visibility = 'public' or e.host_id = auth.uid() or public.is_event_member(e.id)
  ))
);
drop policy if exists event_esports_write on public.event_esports;
create policy event_esports_write on public.event_esports
for all to authenticated
using (public.is_event_host(event_id))
with check (public.is_event_host(event_id));

drop policy if exists event_gatherings_select on public.event_gatherings;
create policy event_gatherings_select on public.event_gatherings
for select to authenticated using (
  exists (select 1 from public.events e where e.id = event_id and (
    e.visibility = 'public' or e.host_id = auth.uid() or public.is_event_member(e.id)
  ))
);
drop policy if exists event_gatherings_write on public.event_gatherings;
create policy event_gatherings_write on public.event_gatherings
for all to authenticated
using (public.is_event_host(event_id))
with check (public.is_event_host(event_id));

-- Event membership: members can see membership; users can request/join through controlled frontend actions;
-- hosts can manage all rows. Implementation can later tighten direct insert behavior with RPCs.
drop policy if exists event_members_select on public.event_members;
create policy event_members_select on public.event_members
for select to authenticated using (
  public.is_event_member(event_id)
  or public.is_event_host(event_id)
  or exists (select 1 from public.events e where e.id = event_id and e.visibility = 'public')
);

drop policy if exists event_members_insert_self on public.event_members;
-- Direct membership inserts are intentionally restricted to hosts.
-- Later, the app should use a transactional join_event() RPC so capacity and status
-- are checked atomically and private events cannot be bypassed.
drop policy if exists event_members_insert_host on public.event_members;
create policy event_members_insert_host on public.event_members
for insert to authenticated
with check (public.is_event_host(event_id));

drop policy if exists event_members_update_host on public.event_members;
create policy event_members_update_host on public.event_members
for update to authenticated
using (public.is_event_host(event_id))
with check (public.is_event_host(event_id));

drop policy if exists event_members_delete_self_or_host on public.event_members;
create policy event_members_delete_self_or_host on public.event_members
for delete to authenticated
using (user_id = auth.uid() or public.is_event_host(event_id));

-- Join requests: requester sees own; host sees requests for hosted events.
drop policy if exists event_join_requests_select on public.event_join_requests;
create policy event_join_requests_select on public.event_join_requests
for select to authenticated using (
  user_id = auth.uid() or public.is_event_host(event_id)
);

drop policy if exists event_join_requests_insert_self on public.event_join_requests;
create policy event_join_requests_insert_self on public.event_join_requests
for insert to authenticated
with check (user_id = auth.uid());

drop policy if exists event_join_requests_update_self_or_host on public.event_join_requests;
create policy event_join_requests_update_self_or_host on public.event_join_requests
for update to authenticated
using (user_id = auth.uid() or public.is_event_host(event_id))
with check (user_id = auth.uid() or public.is_event_host(event_id));

-- Teams: visible to event members; host manages teams; members manage their own membership.
drop policy if exists event_teams_select on public.event_teams;
create policy event_teams_select on public.event_teams
for select to authenticated using (public.is_event_member(event_id) or public.is_event_host(event_id));

drop policy if exists event_teams_write on public.event_teams;
create policy event_teams_write on public.event_teams
for all to authenticated
using (public.is_event_host(event_id))
with check (public.is_event_host(event_id));

drop policy if exists event_team_members_select on public.event_team_members;
create policy event_team_members_select on public.event_team_members
for select to authenticated using (
  exists (
    select 1 from public.event_teams t
    where t.id = team_id
      and public.is_event_member(t.event_id)
  )
);

drop policy if exists event_team_members_insert_self_or_host on public.event_team_members;
create policy event_team_members_insert_self_or_host on public.event_team_members
for insert to authenticated with check (
  user_id = auth.uid()
  or exists (select 1 from public.event_teams t where t.id = team_id and public.is_event_host(t.event_id))
);

drop policy if exists event_team_members_delete_self_or_host on public.event_team_members;
create policy event_team_members_delete_self_or_host on public.event_team_members
for delete to authenticated using (
  user_id = auth.uid()
  or exists (select 1 from public.event_teams t where t.id = team_id and public.is_event_host(t.event_id))
);

-- Friendships are visible to either participant.
drop policy if exists friendships_select_participant on public.friendships;
create policy friendships_select_participant on public.friendships
for select to authenticated using (user_a = auth.uid() or user_b = auth.uid());

-- Friendship creation is intentionally reserved for a future accept_friend_request()
-- transaction so a user cannot create arbitrary friendships from the browser.

drop policy if exists friendships_delete_participant on public.friendships;
create policy friendships_delete_participant on public.friendships
for delete to authenticated using (user_a = auth.uid() or user_b = auth.uid());

-- Friend requests are private to sender/receiver.
drop policy if exists friend_requests_participant on public.friend_requests;
create policy friend_requests_participant on public.friend_requests
for select to authenticated
using (sender_id = auth.uid() or receiver_id = auth.uid());

drop policy if exists friend_requests_insert_sender on public.friend_requests;
create policy friend_requests_insert_sender on public.friend_requests
for insert to authenticated
with check (sender_id = auth.uid() and sender_id <> receiver_id);

-- Ratings: participants in the event can read; raters can create/update their own records.
drop policy if exists ratings_select_event_participant on public.ratings;
create policy ratings_select_event_participant on public.ratings
for select to authenticated using (public.is_event_member(event_id));

drop policy if exists ratings_insert_rater on public.ratings;
create policy ratings_insert_rater on public.ratings
for insert to authenticated with check (
  rater_id = auth.uid()
  and public.is_event_member(event_id)
);

drop policy if exists ratings_update_rater on public.ratings;
create policy ratings_update_rater on public.ratings
for update to authenticated using (rater_id = auth.uid()) with check (rater_id = auth.uid());

drop policy if exists ratings_delete_rater on public.ratings;
create policy ratings_delete_rater on public.ratings
for delete to authenticated using (rater_id = auth.uid());

-- Notifications are private to recipient, with sender optionally retained.
drop policy if exists notifications_recipient on public.notifications;
create policy notifications_recipient on public.notifications
for select to authenticated using (recipient_id = auth.uid());

drop policy if exists notifications_mark_read on public.notifications;
create policy notifications_mark_read on public.notifications
for update to authenticated using (recipient_id = auth.uid()) with check (recipient_id = auth.uid());

-- Event chat is private to event members/host.
drop policy if exists event_messages_select_member on public.event_messages;
create policy event_messages_select_member on public.event_messages
for select to authenticated using (public.is_event_member(event_id));

drop policy if exists event_messages_insert_member on public.event_messages;
create policy event_messages_insert_member on public.event_messages
for insert to authenticated with check (
  sender_id = auth.uid() and public.is_event_member(event_id)
);

drop policy if exists event_messages_update_sender on public.event_messages;
create policy event_messages_update_sender on public.event_messages
for update to authenticated using (sender_id = auth.uid()) with check (sender_id = auth.uid());

drop policy if exists event_messages_delete_sender_or_host on public.event_messages;
create policy event_messages_delete_sender_or_host on public.event_messages
for delete to authenticated using (sender_id = auth.uid() or public.is_event_host(event_id));

-- Realtime-ready tables. If the publication already contains a table, these statements should
-- be adjusted/removed during the actual Supabase deployment migration.
-- alter publication supabase_realtime add table public.event_messages;
-- alter publication supabase_realtime add table public.notifications;
