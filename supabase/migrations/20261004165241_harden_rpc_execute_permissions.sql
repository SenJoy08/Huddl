
-- Internal notification helpers/triggers are never client-facing.
revoke execute on function public.create_notification(uuid, uuid, text, text, uuid, uuid) from anon, public;
revoke execute on function public.notification_preference_enabled(uuid, text) from anon, public;
revoke execute on function public.notify_event_changes() from anon, public;
revoke execute on function public.notify_event_join_request_changes() from anon, public;
revoke execute on function public.notify_event_member_added() from anon, public;
revoke execute on function public.notify_friend_request_changes() from anon, public;

-- Authentication is required for private-event requests and event chat.
-- Keep these available to authenticated users because the app calls them,
-- but ensure the anonymous/public API surface cannot invoke them.
revoke execute on function public.request_event_join(uuid) from anon, public;
revoke execute on function public.send_event_message(uuid, text) from anon, public;

-- This helper is only used by RLS / trusted database logic.
revoke execute on function public.is_discoverable_event(uuid) from anon, public;
;
