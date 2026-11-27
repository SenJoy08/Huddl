
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

revoke execute on function public.is_event_member(uuid) from public, anon, authenticated;
revoke execute on function public.is_event_host(uuid) from public, anon, authenticated;
revoke execute on function public.are_friends(uuid, uuid) from public, anon, authenticated;
revoke execute on function public.add_event_host_as_member() from public, anon, authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.set_updated_at() from public, anon, authenticated;

create policy event_types_select_authenticated on public.event_types
for select to authenticated using (enabled = true);

create policy sports_select_authenticated on public.sports
for select to authenticated using (enabled = true);

create policy skill_levels_select_authenticated on public.skill_levels
for select to authenticated using (true);

create policy esports_games_select_authenticated on public.esports_games
for select to authenticated using (enabled = true);

create policy gathering_types_select_authenticated on public.gathering_types
for select to authenticated using (enabled = true);

create policy profiles_select_authenticated on public.profiles
for select to authenticated using (true);

create policy profiles_insert_own on public.profiles
for insert to authenticated with check (id = auth.uid());

create policy profiles_update_own on public.profiles
for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy profile_sports_select_authenticated on public.profile_sports
for select to authenticated using (true);

create policy profile_sports_insert_own on public.profile_sports
for insert to authenticated with check (profile_id = auth.uid());

create policy profile_sports_update_own on public.profile_sports
for update to authenticated using (profile_id = auth.uid()) with check (profile_id = auth.uid());

create policy profile_sports_delete_own on public.profile_sports
for delete to authenticated using (profile_id = auth.uid());

create policy notification_preferences_own on public.notification_preferences
for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy events_select_discoverable on public.events
for select to authenticated
using (
  visibility = 'public'
  or host_id = auth.uid()
  or exists (select 1 from public.event_members em where em.event_id = events.id and em.user_id = auth.uid())
  or exists (select 1 from public.event_join_requests r where r.event_id = events.id and r.user_id = auth.uid())
);

create policy events_insert_hosted on public.events
for insert to authenticated with check (host_id = auth.uid());

create policy events_update_host on public.events
for update to authenticated using (host_id = auth.uid()) with check (host_id = auth.uid());

create policy events_delete_host on public.events
for delete to authenticated using (host_id = auth.uid());

create policy event_sports_select on public.event_sports
for select to authenticated using (
  exists (
    select 1 from public.events e
    where e.id = event_id
      and (e.visibility = 'public' or e.host_id = auth.uid()
        or exists (select 1 from public.event_members em where em.event_id = e.id and em.user_id = auth.uid()))
  )
);

create policy event_sports_write on public.event_sports
for all to authenticated
using (exists (select 1 from public.events e where e.id = event_id and e.host_id = auth.uid()))
with check (exists (select 1 from public.events e where e.id = event_id and e.host_id = auth.uid()));

create policy event_esports_select on public.event_esports
for select to authenticated using (
  exists (
    select 1 from public.events e
    where e.id = event_id
      and (e.visibility = 'public' or e.host_id = auth.uid()
        or exists (select 1 from public.event_members em where em.event_id = e.id and em.user_id = auth.uid()))
  )
);

create policy event_esports_write on public.event_esports
for all to authenticated
using (exists (select 1 from public.events e where e.id = event_id and e.host_id = auth.uid()))
with check (exists (select 1 from public.events e where e.id = event_id and e.host_id = auth.uid()));

create policy event_gatherings_select on public.event_gatherings
for select to authenticated using (
  exists (
    select 1 from public.events e
    where e.id = event_id
      and (e.visibility = 'public' or e.host_id = auth.uid()
        or exists (select 1 from public.event_members em where em.event_id = e.id and em.user_id = auth.uid()))
  )
);

create policy event_gatherings_write on public.event_gatherings
for all to authenticated
using (exists (select 1 from public.events e where e.id = event_id and e.host_id = auth.uid()))
with check (exists (select 1 from public.events e where e.id = event_id and e.host_id = auth.uid()));

create policy event_members_select on public.event_members
for select to authenticated using (
  user_id = auth.uid()
  or exists (select 1 from public.events e where e.id = event_id and e.host_id = auth.uid())
  or exists (select 1 from public.events e where e.id = event_id and e.visibility = 'public')
);

create policy event_members_insert_host on public.event_members
for insert to authenticated with check (
  exists (select 1 from public.events e where e.id = event_id and e.host_id = auth.uid())
);

create policy event_members_update_host on public.event_members
for update to authenticated
using (exists (select 1 from public.events e where e.id = event_id and e.host_id = auth.uid()))
with check (exists (select 1 from public.events e where e.id = event_id and e.host_id = auth.uid()));

create policy event_members_delete_self_or_host on public.event_members
for delete to authenticated using (
  user_id = auth.uid()
  or exists (select 1 from public.events e where e.id = event_id and e.host_id = auth.uid())
);

create policy event_join_requests_select on public.event_join_requests
for select to authenticated using (
  user_id = auth.uid()
  or exists (select 1 from public.events e where e.id = event_id and e.host_id = auth.uid())
);

create policy event_join_requests_insert_self on public.event_join_requests
for insert to authenticated with check (user_id = auth.uid());

create policy event_join_requests_update_self_or_host on public.event_join_requests
for update to authenticated
using (
  user_id = auth.uid()
  or exists (select 1 from public.events e where e.id = event_id and e.host_id = auth.uid())
)
with check (
  user_id = auth.uid()
  or exists (select 1 from public.events e where e.id = event_id and e.host_id = auth.uid())
);

create policy event_teams_select on public.event_teams
for select to authenticated using (
  exists (select 1 from public.events e where e.id = event_id and
    (e.host_id = auth.uid() or exists (select 1 from public.event_members em where em.event_id = e.id and em.user_id = auth.uid())))
);

create policy event_teams_write on public.event_teams
for all to authenticated
using (exists (select 1 from public.events e where e.id = event_id and e.host_id = auth.uid()))
with check (exists (select 1 from public.events e where e.id = event_id and e.host_id = auth.uid()));

create policy event_team_members_select on public.event_team_members
for select to authenticated using (
  exists (
    select 1 from public.event_teams t
    where t.id = team_id
      and exists (select 1 from public.event_members em where em.event_id = t.event_id and em.user_id = auth.uid())
  )
);

create policy event_team_members_insert_self_or_host on public.event_team_members
for insert to authenticated with check (
  user_id = auth.uid()
  or exists (
    select 1 from public.event_teams t
    where t.id = team_id
      and exists (select 1 from public.events e where e.id = t.event_id and e.host_id = auth.uid())
  )
);

create policy event_team_members_delete_self_or_host on public.event_team_members
for delete to authenticated using (
  user_id = auth.uid()
  or exists (
    select 1 from public.event_teams t
    where t.id = team_id
      and exists (select 1 from public.events e where e.id = t.event_id and e.host_id = auth.uid())
  )
);

create policy friendships_select_participant on public.friendships
for select to authenticated using (user_a = auth.uid() or user_b = auth.uid());

create policy friendships_delete_participant on public.friendships
for delete to authenticated using (user_a = auth.uid() or user_b = auth.uid());

create policy friend_requests_participant on public.friend_requests
for select to authenticated using (sender_id = auth.uid() or receiver_id = auth.uid());

create policy friend_requests_insert_sender on public.friend_requests
for insert to authenticated with check (sender_id = auth.uid() and sender_id <> receiver_id);

create policy ratings_select_event_participant on public.ratings
for select to authenticated using (
  exists (select 1 from public.event_members em where em.event_id = ratings.event_id and em.user_id = auth.uid())
);

create policy ratings_insert_rater on public.ratings
for insert to authenticated with check (
  rater_id = auth.uid()
  and exists (select 1 from public.event_members em where em.event_id = ratings.event_id and em.user_id = auth.uid())
);

create policy ratings_update_rater on public.ratings
for update to authenticated using (rater_id = auth.uid()) with check (rater_id = auth.uid());

create policy ratings_delete_rater on public.ratings
for delete to authenticated using (rater_id = auth.uid());

create policy notifications_recipient on public.notifications
for select to authenticated using (recipient_id = auth.uid());

create policy notifications_mark_read on public.notifications
for update to authenticated using (recipient_id = auth.uid()) with check (recipient_id = auth.uid());

create policy event_messages_select_member on public.event_messages
for select to authenticated using (
  exists (select 1 from public.event_members em where em.event_id = event_messages.event_id and em.user_id = auth.uid())
);

create policy event_messages_insert_member on public.event_messages
for insert to authenticated with check (
  sender_id = auth.uid()
  and exists (select 1 from public.event_members em where em.event_id = event_messages.event_id and em.user_id = auth.uid())
);

create policy event_messages_update_sender on public.event_messages
for update to authenticated using (sender_id = auth.uid()) with check (sender_id = auth.uid());

create policy event_messages_delete_sender_or_host on public.event_messages
for delete to authenticated using (
  sender_id = auth.uid()
  or exists (select 1 from public.events e where e.id = event_messages.event_id and e.host_id = auth.uid())
);
;
