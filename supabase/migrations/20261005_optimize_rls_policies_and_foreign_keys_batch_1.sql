-- Reduce redundant permissive RLS policies and add covering indexes for
-- foreign keys flagged by the Supabase performance advisor.

drop policy if exists event_esports_write on public.event_esports;
create policy event_esports_insert_host
on public.event_esports
for insert
to authenticated
with check (private.is_event_host(event_id));

create policy event_esports_update_host
on public.event_esports
for update
to authenticated
using (private.is_event_host(event_id))
with check (private.is_event_host(event_id));

create policy event_esports_delete_host
on public.event_esports
for delete
to authenticated
using (private.is_event_host(event_id));

drop policy if exists event_gatherings_write on public.event_gatherings;
create policy event_gatherings_insert_host
on public.event_gatherings
for insert
to authenticated
with check (private.is_event_host(event_id));

create policy event_gatherings_update_host
on public.event_gatherings
for update
to authenticated
using (private.is_event_host(event_id))
with check (private.is_event_host(event_id));

create policy event_gatherings_delete_host
on public.event_gatherings
for delete
to authenticated
using (private.is_event_host(event_id));

drop policy if exists event_teams_write on public.event_teams;
create policy event_teams_insert_host
on public.event_teams
for insert
to authenticated
with check (private.is_event_host(event_id));

create policy event_teams_update_host
on public.event_teams
for update
to authenticated
using (private.is_event_host(event_id))
with check (private.is_event_host(event_id));

create policy event_teams_delete_host
on public.event_teams
for delete
to authenticated
using (private.is_event_host(event_id));

drop policy if exists event_sports_write on public.event_sports;
create policy event_sports_insert_host
on public.event_sports
for insert
to authenticated
with check (private.is_event_host(event_id));

create policy event_sports_update_host
on public.event_sports
for update
to authenticated
using (private.is_event_host(event_id))
with check (private.is_event_host(event_id));

create policy event_sports_delete_host
on public.event_sports
for delete
to authenticated
using (private.is_event_host(event_id));

drop policy if exists event_members_insert_host on public.event_members;
drop policy if exists event_members_insert_self_public on public.event_members;
create policy event_members_insert
on public.event_members
for insert
to authenticated
with check (
  private.is_event_host(event_id)
  or (
    user_id = auth.uid()
    and role = 'member'
    and exists (
      select 1
      from public.events e
      where e.id = event_members.event_id
        and e.visibility = 'public'
        and e.status in ('upcoming', 'full')
        and e.host_id <> auth.uid()
    )
  )
);

drop policy if exists friend_requests_update_sender_resend on public.friend_requests;
drop policy if exists friend_requests_update_receiver_decide on public.friend_requests;
drop policy if exists friend_requests_update_participant_remove on public.friend_requests;
create policy friend_requests_update_participant
on public.friend_requests
for update
to authenticated
using (
  (sender_id = auth.uid() and status in ('declined', 'cancelled'))
  or (receiver_id = auth.uid() and status = 'pending')
  or ((sender_id = auth.uid() or receiver_id = auth.uid()) and status = 'accepted')
)
with check (
  (sender_id = auth.uid() and status = 'pending')
  or (receiver_id = auth.uid() and status in ('accepted', 'declined'))
  or ((sender_id = auth.uid() or receiver_id = auth.uid()) and status = 'cancelled')
);

create index if not exists event_esports_skill_level_code_idx
  on public.event_esports(skill_level_code);
create index if not exists event_gatherings_gathering_type_code_idx
  on public.event_gatherings(gathering_type_code);
create index if not exists event_messages_sender_id_idx
  on public.event_messages(sender_id);
create index if not exists event_sports_skill_level_code_idx
  on public.event_sports(skill_level_code);
create index if not exists notifications_actor_id_idx
  on public.notifications(actor_id);
create index if not exists notifications_event_id_idx
  on public.notifications(event_id);
create index if not exists notifications_friend_request_id_idx
  on public.notifications(friend_request_id);
create index if not exists profile_sports_skill_level_code_idx
  on public.profile_sports(skill_level_code);

drop index if exists public.notifications_recipient_created_at_idx;
