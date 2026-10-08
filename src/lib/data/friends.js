import { supabase } from '$lib/supabase/client.js';

/** @typedef {{ id: string, name: string, handle: string, sports: string, status: string, color: string }} HuddlFriend */
/** @typedef {{ id: string, name: string, handle: string, sports: string, color: string }} FriendCandidate */
/** @typedef {{ id: string, name: string, handle: string, sports: string, color: string, relation: 'none' | 'friend' | 'incoming' | 'outgoing', requestId?: string }} FriendSearchPerson */
/** @typedef {{ id: string, name: string, handle: string, sports: string, color: string, senderId: string }} IncomingFriendRequest */

const AVATAR_COLORS = ['blue', 'peach', 'lavender', 'mint'];

/** @param {string} id */
function colorForId(id) {
  let hash = 0;
  for (let index = 0; index < id.length; index += 1) hash = (hash * 31 + id.charCodeAt(index)) | 0;
  return AVATAR_COLORS[Math.abs(hash) % AVATAR_COLORS.length];
}

/** @param {unknown} value */
function formatSports(value) {
  return typeof value === 'string' && value.trim() ? value : 'No sports added';
}

/**
 * Load the current user's friends, incoming requests and people available to add.
 * @param {string} userId
 * @returns {Promise<{ friends: HuddlFriend[], candidates: FriendCandidate[], incomingRequests: IncomingFriendRequest[], people: FriendSearchPerson[] }>}
 */
export async function loadFriends(userId) {
  const [friendshipsResult, incomingResult, outgoingResult, profilesResult, profileSportsResult] = await Promise.all([
    supabase
      .from('friendships')
      .select('user_a, user_b')
      .or(`user_a.eq.${userId},user_b.eq.${userId}`),
    supabase
      .from('friend_requests')
      .select('id, sender_id, receiver_id, status')
      .eq('receiver_id', userId)
      .eq('status', 'pending'),
    supabase
      .from('friend_requests')
      .select('id, sender_id, receiver_id, status')
      .eq('sender_id', userId)
      .eq('status', 'pending'),
    supabase
      .from('profiles')
      .select('id, display_name, handle, bio')
      .neq('id', userId)
      .order('display_name', { ascending: true })
      .limit(250),
    supabase
      .from('profile_sports')
      .select('profile_id, sport_id')
  ]);

  const firstError = friendshipsResult.error
    ?? incomingResult.error
    ?? outgoingResult.error
    ?? profilesResult.error
    ?? profileSportsResult.error;
  if (firstError) throw firstError;

  const friendshipRows = friendshipsResult.data ?? [];
  const incomingRows = incomingResult.data ?? [];
  const outgoingRows = outgoingResult.data ?? [];
  const profiles = profilesResult.data ?? [];
  const profileSports = profileSportsResult.data ?? [];

  const sportIds = [...new Set(profileSports.map((row) => row.sport_id))];
  /** @type {{ id: string, name: string }[]} */
  let sportRows = [];

  if (sportIds.length) {
    const { data, error } = await supabase
      .from('sports')
      .select('id, name')
      .in('id', sportIds);
    if (error) throw error;
    sportRows = data ?? [];
  }

  const sportNameById = new Map(sportRows.map((row) => [row.id, row.name]));
  /** @type {Map<string, string[]>} */
  const sportsByProfile = new Map();

  for (const row of profileSports) {
    const sportName = sportNameById.get(row.sport_id);
    if (!sportName) continue;
    const current = sportsByProfile.get(row.profile_id) ?? [];
    current.push(sportName);
    sportsByProfile.set(row.profile_id, current);
  }

  /** @param {string} profileId */
  function profileShape(profileId) {
    const profile = profiles.find((item) => item.id === profileId);
    if (!profile) return null;
    const names = sportsByProfile.get(profileId) ?? [];
    return {
      id: profile.id,
      name: profile.display_name ?? 'Player',
      handle: profile.handle ?? '@player',
      sports: formatSports(names.join(' · ')),
      color: colorForId(profile.id)
    };
  }

  /** @type {Set<string>} */
  const friendIds = new Set(
    friendshipRows.map((row) => row.user_a === userId ? row.user_b : row.user_a)
  );
  /** @type {Set<string>} */
  const incomingIds = new Set(incomingRows.map((row) => row.sender_id));
  /** @type {Set<string>} */
  const outgoingIds = new Set(outgoingRows.map((row) => row.receiver_id));

  /** @type {HuddlFriend[]} */
  const friends = [];
  for (const friendId of friendIds) {
    const shape = profileShape(friendId);
    if (shape) friends.push({ ...shape, status: 'connected' });
  }

  /** @type {IncomingFriendRequest[]} */
  const incomingRequests = [];
  for (const request of incomingRows) {
    const shape = profileShape(request.sender_id);
    if (shape) incomingRequests.push({ ...shape, id: request.id, senderId: request.sender_id });
  }

  /** @type {FriendCandidate[]} */
  const candidates = [];
  /** @type {FriendSearchPerson[]} */
  const people = [];

  const incomingRequestBySender = new Map(incomingRows.map((row) => [row.sender_id, row.id]));
  const outgoingRequestByReceiver = new Map(outgoingRows.map((row) => [row.receiver_id, row.id]));

  for (const profile of profiles) {
    const id = profile.id;
    const shape = profileShape(id);
    if (!shape) continue;

    /** @type {'none' | 'friend' | 'incoming' | 'outgoing'} */
    let relation = 'none';
    let requestId;
    if (friendIds.has(id)) {
      relation = 'friend';
    } else if (incomingIds.has(id)) {
      relation = 'incoming';
      requestId = incomingRequestBySender.get(id);
    } else if (outgoingIds.has(id)) {
      relation = 'outgoing';
      requestId = outgoingRequestByReceiver.get(id);
    }

    people.push({ ...shape, relation, ...(requestId ? { requestId } : {}) });

    if (relation === 'none') {
      candidates.push(shape);
    }
  }

  return { friends, candidates, incomingRequests, people };
}

/** @param {string} receiverId */
export async function sendFriendRequest(receiverId) {
  const { data, error } = await supabase.rpc('send_friend_request', {
    p_receiver_id: receiverId
  });
  if (error) throw error;
  return data;
}

/** @param {string} requestId @param {boolean} accept */
export async function respondFriendRequest(requestId, accept) {
  const { data, error } = await supabase.rpc('respond_friend_request', {
    p_request_id: requestId,
    p_accept: accept
  });
  if (error) throw error;
  return data;
}

/** @param {string} friendId */
export async function removeFriend(friendId) {
  const { data, error } = await supabase.rpc('remove_friend', {
    p_friend_id: friendId
  });
  if (error) throw error;
  return data;
}
