create or replace function private.has_event_join_request(target_event uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.event_join_requests r
    where r.event_id = target_event
      and r.user_id = auth.uid()
      and r.status = 'pending'
  );
$function$;;
