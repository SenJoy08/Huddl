
revoke execute on function public.notification_preference_enabled(uuid, text) from public, authenticated;
revoke execute on function public.create_notification(uuid, uuid, text, text, uuid, uuid) from public, authenticated;
revoke execute on function public.notify_friend_request_changes() from public, authenticated;
revoke execute on function public.notify_event_join_request_changes() from public, authenticated;
revoke execute on function public.notify_event_member_added() from public, authenticated;
revoke execute on function public.notify_event_changes() from public, authenticated;
;
