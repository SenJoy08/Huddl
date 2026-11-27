
alter function public.join_event(uuid) security definer;
alter function public.join_event(uuid) set search_path = public, pg_catalog;

alter function public.respond_friend_request(uuid, boolean) security definer;
alter function public.respond_friend_request(uuid, boolean) set search_path = public, pg_catalog;
;
