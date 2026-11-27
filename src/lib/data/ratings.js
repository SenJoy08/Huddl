import { supabase } from '$lib/supabase/client.js';

/**
 * @typedef {{
 *   id: string,
 *   name: string,
 *   role: string,
 *   stars: number,
 *   showedUp: boolean,
 *   skillMatch: boolean | null,
 *   note: string,
 *   canMarkAttendance: boolean
 * }} RatingPlayer
 */

/**
 * Load the players the current user can rate for a completed event.
 * Existing ratings from this rater are returned so the form can be resumed.
 * @param {string} eventId
 * @param {string} userId
 * @returns {Promise<RatingPlayer[]>}
 */
export async function loadRatingPlayers(eventId, userId) {
  const [eventResult, memberResult, ratingResult] = await Promise.all([
    supabase.rpc('get_event_rating_context', { p_event_id: eventId }),
    supabase
      .from('event_members')
      .select('user_id, role')
      .eq('event_id', eventId),
    supabase
      .from('ratings')
      .select('ratee_id, score, showed_up, skill_match, note')
      .eq('event_id', eventId)
      .eq('rater_id', userId)
  ]);

  const firstError = eventResult.error ?? memberResult.error ?? ratingResult.error;
  if (firstError) throw firstError;
  const eventContext = eventResult.data?.[0];
  if (!eventContext) throw new Error('Only participants can rate a completed event.');
  if (eventContext.status !== 'completed') throw new Error('Ratings are available after the event is completed.');

  const allMembers = memberResult.data ?? [];
  if (!allMembers.some((member) => member.user_id === userId)) {
    throw new Error('Only event participants can rate players.');
  }
  const isHost = eventContext.host_id === userId;
  const memberRows = allMembers.filter((member) => member.user_id !== userId);
  if (!memberRows.length) return [];

  const playerIds = memberRows.map((row) => row.user_id);
  const { data: profileRows, error: profileError } = await supabase
    .from('profiles')
    .select('id, display_name')
    .in('id', playerIds);

  if (profileError) throw profileError;

  const profileNameById = new Map(
    (profileRows ?? []).map((row) => [row.id, row.display_name])
  );
  const ratingByPlayerId = new Map(
    (ratingResult.data ?? []).map((row) => [row.ratee_id, row])
  );

  return memberRows.map((member) => {
    const existing = ratingByPlayerId.get(member.user_id);
    return {
      id: member.user_id,
      name: profileNameById.get(member.user_id) ?? 'Player',
      role: member.role === 'host' ? 'Host' : 'Player',
      stars: existing?.score ?? 0,
      showedUp: existing?.showed_up ?? true,
      skillMatch: existing?.skill_match ?? true,
      note: existing?.note ?? '',
      // Participants can submit stars; attendance and skill-match are host-only.
      canMarkAttendance: isHost
    };
  });
}

/**
 * Persist one player's post-game rating.
 * @param {{eventId:string, playerId:string, stars:number, showedUp:boolean, skillMatch:boolean|null, note?:string}} rating
 */
export async function submitPlayerRating(rating) {
  const score = rating.showedUp ? Math.trunc(Number(rating.stars)) : null;
  const skillMatch = rating.showedUp ? rating.skillMatch : null;

  const { data, error } = await supabase.rpc('submit_rating', {
    p_event_id: rating.eventId,
    p_ratee_id: rating.playerId,
    p_score: score,
    p_showed_up: rating.showedUp,
    p_skill_match: skillMatch,
    p_note: rating.note?.trim() || null
  });

  if (error) throw error;
  return data;
}


/**
 * Persist that the event host has completed the post-game rating step.
 * A database RPC validates host ownership and completed-event status.
 * @param {string} eventId
 * @returns {Promise<void>}
 */
export async function markHostRatingsComplete(eventId) {
  const { error } = await supabase.rpc('mark_host_ratings_complete', {
    p_event_id: eventId
  });

  if (error) throw error;
}
