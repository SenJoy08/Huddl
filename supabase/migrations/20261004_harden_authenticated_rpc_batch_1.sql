-- Batch 1: convert safe authenticated-facing SECURITY DEFINER RPCs to SECURITY INVOKER.
-- Tighten the supporting RLS policies so the invoker path retains the same authorization boundary.

alter function public.decide_event_join_request(uuid, boolean)
  security invoker;

create policy friend_requests_update_sender_resend
on public.friend_requests
for update
to authenticated
using (
  sender_id = auth.uid()
  and status in ('declined', 'cancelled')
)
with check (
  sender_id = auth.uid()
  and status = 'pending'
);

create policy friend_requests_update_receiver_decide
on public.friend_requests
for update
to authenticated
using (
  receiver_id = auth.uid()
  and status = 'pending'
)
with check (
  receiver_id = auth.uid()
  and status in ('accepted', 'declined')
);

create policy friend_requests_update_participant_remove
on public.friend_requests
for update
to authenticated
using (
  (sender_id = auth.uid() or receiver_id = auth.uid())
  and status = 'accepted'
)
with check (
  (sender_id = auth.uid() or receiver_id = auth.uid())
  and status = 'cancelled'
);

alter function public.send_friend_request(uuid)
  security invoker;

alter function public.respond_friend_request(uuid, boolean)
  security invoker;

alter function public.remove_friend(uuid)
  security invoker;

drop policy if exists event_messages_insert_member on public.event_messages;

create policy event_messages_insert_member
on public.event_messages
for insert
to authenticated
with check (
  sender_id = auth.uid()
  and btrim(body) <> ''
  and exists (
    select 1
    from public.event_members em
    join public.events e on e.id = em.event_id
    where em.event_id = event_messages.event_id
      and em.user_id = auth.uid()
      and e.status not in ('completed', 'cancelled')
  )
);

alter function public.send_event_message(uuid, text)
  security invoker;

do $$
begin
  if not exists (
    select 1
    from pg_constraint c
    where c.conrelid = 'public.event_messages'::regclass
      and c.contype = 'c'
      and c.conname = 'event_messages_body_nonempty'
  ) then
    alter table public.event_messages
      add constraint event_messages_body_nonempty
      check (btrim(body) <> '');
  end if;
end $$;
