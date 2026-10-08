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
  const [memberResult, ratingResult] = await Promise.all([
    supabase
      .from('event_members')
      .select('user_id, role')
      .eq('event_id', eventId)
      .neq('user_id', userId),
    supabase
      .from('ratings')
      .select('ratee_id, score, showed_up, skill_match, note')
      .eq('event_id', eventId)
      .eq('rater_id', userId)
  ]);

  const firstError = memberResult.error ?? ratingResult.error;
  if (firstError) throw firstError;

  const memberRows = memberResult.data ?? [];
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
      // The current rating flow is host-only, so the caller may mark attendance.
      canMarkAttendance: true
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
 * The database RLS policy ensures only the event host can update this field.
 * @param {string} eventId
 * @returns {Promise<void>}
 */
export async function markHostRatingsComplete(eventId) {
  const { data, error } = await supabase
    .from('events')
    .update({ host_rated_at: new Date().toISOString() })
    .eq('id', eventId)
    .select('id')
    .maybeSingle();

  if (error) throw error;
  if (!data?.id) throw new Error('Only the event host can complete ratings.');
}
