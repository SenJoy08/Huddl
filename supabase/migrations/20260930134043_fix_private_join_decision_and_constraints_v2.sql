
alter function public.decide_event_join_request(uuid, boolean) security definer;
alter function public.decide_event_join_request(uuid, boolean) set search_path = public, pg_catalog;

alter table public.event_join_requests
  drop constraint if exists event_join_requests_event_user_key;
;
