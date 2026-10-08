import { supabase } from '$lib/supabase/client.js';

/**
 * @typedef {{ games: number, hosted: number, rating: number|null, ratingCount: number, attendance: number|null, sports: { name: string, games: number }[] }} HuddlStats
 */

/** @type {HuddlStats} */
export const EMPTY_STATS = {
  games: 0,
  hosted: 0,
  rating: null,
  ratingCount: 0,
  attendance: null,
  sports: []
};

/** @param {string} userId */
async function loadStatsForUser(userId) {
  const { data: memberRows, error: memberError } = await supabase
    .from('event_members')
    .select('event_id, role, showed_up')
    .eq('user_id', userId);

  if (memberError) throw memberError;

  const eventIds = [...new Set((memberRows ?? []).map((row) => row.event_id))];
  if (!eventIds.length) return { ...EMPTY_STATS, sports: [] };

  const { data: eventRows, error: eventError } = await supabase
    .from('events')
    .select('id, event_type_code, status')
    .in('id', eventIds)
    .eq('status', 'completed');

  if (eventError) throw eventError;

  const completedEvents = eventRows ?? [];
  const completedEventIds = completedEvents.map((row) => row.id);
  if (!completedEventIds.length) return { ...EMPTY_STATS, sports: [] };

  const completedEventIdSet = new Set(completedEventIds);
  const completedMemberships = (memberRows ?? []).filter((row) => completedEventIdSet.has(row.event_id));

  const [sportResult, esportsResult, ratingResult] = await Promise.all([
    supabase
      .from('event_sports')
      .select('event_id, sport_id')
      .in('event_id', completedEventIds),
    supabase
      .from('event_esports')
      .select('event_id, game_id')
      .in('event_id', completedEventIds),
    supabase
      .from('ratings')
      .select('event_id, score, showed_up')
      .eq('ratee_id', userId)
      .in('event_id', completedEventIds)
      .not('score', 'is', null)
  ]);

  const firstError = sportResult.error ?? esportsResult.error ?? ratingResult.error;
  if (firstError) throw firstError;

  const sportIds = [...new Set((sportResult.data ?? []).map((row) => row.sport_id))];
  const gameIds = [...new Set((esportsResult.data ?? []).map((row) => row.game_id))];

  const [sportsLookup, esportsLookup] = await Promise.all([
    sportIds.length
      ? supabase.from('sports').select('id, name').in('id', sportIds)
      : Promise.resolve({ data: [], error: null }),
    gameIds.length
      ? supabase.from('esports_games').select('id, name').in('id', gameIds)
      : Promise.resolve({ data: [], error: null })
  ]);

  const lookupError = sportsLookup.error ?? esportsLookup.error;
  if (lookupError) throw lookupError;

  const sportNameById = new Map((sportsLookup.data ?? []).map((row) => [row.id, row.name]));
  const gameNameById = new Map((esportsLookup.data ?? []).map((row) => [row.id, row.name]));
  const gamesByName = new Map();

  for (const row of sportResult.data ?? []) {
    const name = sportNameById.get(row.sport_id);
    if (!name) continue;
    gamesByName.set(name, (gamesByName.get(name) ?? 0) + 1);
  }

  for (const row of esportsResult.data ?? []) {
    const name = gameNameById.get(row.game_id);
    if (!name) continue;
    gamesByName.set(name, (gamesByName.get(name) ?? 0) + 1);
  }

  const sports = [...gamesByName.entries()]
    .map(([name, games]) => ({ name, games }))
    .sort((a, b) => b.games - a.games || a.name.localeCompare(b.name));

  const receivedScores = (ratingResult.data ?? [])
    .map((row) => Number(row.score))
    .filter((score) => Number.isFinite(score) && score >= 1 && score <= 5);

  const rating = receivedScores.length
    ? Math.round((receivedScores.reduce((sum, score) => sum + score, 0) / receivedScores.length) * 10) / 10
    : null;

  const knownAttendance = completedMemberships.filter((row) => row.showed_up === true || row.showed_up === false);
  const attendance = knownAttendance.length > 0
    ? Math.round((knownAttendance.filter((row) => row.showed_up === true).length / knownAttendance.length) * 100)
    : null;

  return {
    games: completedEventIds.length,
    hosted: completedMemberships.filter((row) => row.role === 'host').length,
    rating,
    ratingCount: receivedScores.length,
    attendance,
    sports
  };
}

/**
 * Load the signed-in user's completed-game statistics from Supabase.
 * Includes regular sports and esports events.
 * @param {string} userId
 * @returns {Promise<HuddlStats>}
 */
export async function loadUserStats(userId) {
  return loadStatsForUser(userId);
}

/**
 * Load a public player's completed-game statistics through the hardened RPC.
 * The RPC runs the privileged aggregation server-side and exposes only the
 * public statistics shape needed by player profiles.
 * @param {string} userId
 * @returns {Promise<HuddlStats>}
 */
export async function loadPlayerStats(userId) {
  if (!userId) return { ...EMPTY_STATS, sports: [] };

  const { data, error } = await supabase.rpc('get_public_player_stats', {
    p_user_id: userId
  });

  if (error) throw error;

  /** @type {{ name?: unknown, games?: unknown }[]} */
  const publicSports = Array.isArray(data?.sports) ? data.sports : [];

  return {
    games: Number(data?.games ?? 0),
    hosted: Number(data?.hosted ?? 0),
    rating: data?.rating === null || data?.rating === undefined ? null : Number(data.rating),
    ratingCount: Number(data?.ratingCount ?? 0),
    attendance: data?.attendance === null || data?.attendance === undefined ? null : Number(data.attendance),
    sports: publicSports
      .map((sport) => ({ name: String(sport?.name ?? ''), games: Number(sport?.games ?? 0) }))
      .filter((sport) => sport.name && Number.isFinite(sport.games))
  };
}
