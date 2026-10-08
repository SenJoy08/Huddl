-- Supabase recommends wrapping auth.uid()/auth.jwt() calls in a SELECT
-- subquery inside RLS policies so PostgreSQL can evaluate them once per
-- statement instead of repeatedly for every row.

do $$
declare
  p record;
  using_expr text;
  check_expr text;
  stmt text;
begin
  for p in
    select schemaname, tablename, policyname, qual, with_check
    from pg_policies
    where schemaname = 'public'
      and (
        coalesce(qual, '') like '%auth.uid()%'
        or coalesce(with_check, '') like '%auth.uid()%'
      )
  loop
    using_expr := case
      when p.qual is null then null
      else replace(p.qual, 'auth.uid()', '(select auth.uid())')
    end;

    check_expr := case
      when p.with_check is null then null
      else replace(p.with_check, 'auth.uid()', '(select auth.uid())')
    end;

    stmt := format(
      'alter policy %I on %I.%I',
      p.policyname,
      p.schemaname,
      p.tablename
    );

    if using_expr is not null then
      stmt := stmt || format(' using (%s)', using_expr);
    end if;

    if check_expr is not null then
      stmt := stmt || format(' with check (%s)', check_expr);
    end if;

    execute stmt;
  end loop;
end $$;
