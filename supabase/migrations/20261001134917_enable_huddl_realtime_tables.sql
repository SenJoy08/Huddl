
do $do$
declare
  t text;
  tables_to_add text[] := array[
    'events',
    'event_sports',
    'event_esports',
    'event_gatherings',
    'event_members',
    'event_join_requests',
    'friend_requests',
    'friendships',
    'ratings',
    'event_messages'
  ];
begin
  if exists (
    select 1
    from pg_catalog.pg_publication
    where pubname = 'supabase_realtime'
  ) then
    foreach t in array tables_to_add loop
      if not exists (
        select 1
        from pg_catalog.pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = t
      ) then
        execute format('alter publication supabase_realtime add table public.%I', t);
      end if;
    end loop;
  end if;
end
$do$;
;
