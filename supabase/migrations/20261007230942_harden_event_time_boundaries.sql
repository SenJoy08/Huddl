
    drop policy if exists "events_select_discoverable" on public.events;

    create policy "events_select_discoverable"
    on public.events
    for select
    using (
      (
        status = any (array['upcoming'::text, 'full'::text])
        and visibility = 'public'::text
        and starts_at > now()
      )
      or host_id = (select auth.uid())
      or private.is_event_member(id)
      or private.has_event_join_request(id)
    );

    create or replace function public.join_event(p_event_id uuid)
    returns text
    language plpgsql
    set search_path to 'public', 'pg_catalog'
    as $function$
    declare
      v_event public.events%rowtype;
      v_member_count integer;
    begin
      if auth.uid() is null then
        raise exception 'Not authenticated';
      end if;

      perform pg_advisory_xact_lock(hashtextextended(p_event_id::text, 0));

      select *
      into v_event
      from public.events
      where id = p_event_id;

      if not found then
        raise exception 'Event not found';
      end if;

      if v_event.visibility <> 'public' then
        raise exception 'Private events require a join request';
      end if;

      if v_event.starts_at <= now() or v_event.status in ('completed', 'cancelled') then
        raise exception 'Event is no longer joinable';
      end if;

      if exists (
        select 1
        from public.event_members
        where event_id = p_event_id
          and user_id = auth.uid()
      ) then
        return 'already_member';
      end if;

      select count(*) into v_member_count
      from public.event_members
      where event_id = p_event_id;

      if v_member_count >= v_event.capacity then
        return 'full';
      end if;

      insert into public.event_members (event_id, user_id, role)
      values (p_event_id, auth.uid(), 'member');

      return 'joined';
    end;
    $function$;

    create or replace function public.request_event_join(p_event_id uuid)
    returns text
    language plpgsql
    set search_path to 'public', 'pg_catalog'
    as $function$
    declare
      v_event public.events%rowtype;
    begin
      if auth.uid() is null then
        raise exception 'Not authenticated';
      end if;

      select *
      into v_event
      from public.events
      where id = p_event_id;

      if not found then
        raise exception 'Event not found';
      end if;

      if v_event.host_id = auth.uid() then
        return 'already_member';
      end if;

      if v_event.visibility <> 'private' then
        raise exception 'This event is public; join it directly';
      end if;

      if v_event.starts_at <= now() or v_event.status in ('completed', 'cancelled') then
        raise exception 'Event is no longer joinable';
      end if;

      if exists (
        select 1
        from public.event_members
        where event_id = p_event_id
          and user_id = auth.uid()
      ) then
        return 'already_member';
      end if;

      if v_event.status = 'full' then
        return 'full';
      end if;

      insert into public.event_join_requests (event_id, user_id, status, decided_at)
      values (p_event_id, auth.uid(), 'pending', null)
      on conflict (event_id, user_id)
      do update
        set status = 'pending',
            decided_at = null;

      return 'requested';
    end;
    $function$;
  ;
