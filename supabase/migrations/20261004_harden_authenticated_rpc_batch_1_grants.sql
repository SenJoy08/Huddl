-- The SECURITY INVOKER friend RPCs now rely on normal table privileges + RLS.
-- Grant only the additional operations those RPCs require.

grant update on table public.friend_requests to authenticated;
grant insert on table public.friendships to authenticated;
