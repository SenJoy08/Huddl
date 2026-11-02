
insert into public.friendships (user_a, user_b)
select distinct
  least(r.sender_id, r.receiver_id),
  greatest(r.sender_id, r.receiver_id)
from public.friend_requests r
where r.status = 'accepted'
on conflict (user_a, user_b) do nothing;
;
