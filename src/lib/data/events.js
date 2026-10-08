import { supabase } from '$lib/supabase/client.js';

/** @typedef {{ event_id: string, user_id: string, role: string }} EventMemberRow */
/** @typedef {{ id: string, event_id: string, user_id: string, status: string }} EventRequestRow */
/** @typedef {{ id: string, display_name: string|null, handle: string|null }} ProfileRow */

/** @typedef {{ id: string, eventType: 'sport' | 'esports', sport: string, gameId?: string, title: string, startsAt: string, date: string, dateValue: string, time: string, location: string, host: string, hostId: string, members: number, capacity: number, skill: string, color: string, description: string, visibility: string, status: string, pendingRequests: number, pendingRequestId?: string|null, isMember: boolean, ratingsSubmitted?: boolean, platform?: string|null, gameMode?: string|null, memberProfiles?: { id:string,name:string,handle:string,color:string }[] }} HuddlEvent */

/** @type {Record<string, string>} */
const COLOR_BY_SPORT = {
  Football: 'blue',
  Badminton: 'peach',
  Basketball: 'lavender'
};

/** @param {string} sport */
function colorForSport(sport) {
  return COLOR_BY_SPORT[sport] ?? 'mint';
}

/** @param {string} id */
function colorForId(id) {
  const colors = ['blue', 'peach', 'lavender', 'mint'];
  let hash = 0;
  for (let index = 0; index < id.length; index += 1) hash = (hash * 31 + id.charCodeAt(index)) | 0;
  return colors[Math.abs(hash) % colors.length];
}

/** @param {string} value */
function dateValueFromTimestamp(value) {
  const date = new Date(value);
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

/** @param {string} value */
function timeValueFromTimestamp(value) {
  const date = new Date(value);
  return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
}

/** @param {string} value */
function displayDateTimeFromTimestamp(value) {
  const date = new Date(value);
  const dateText = date.toLocaleDateString('en-IN', {
    weekday: 'short',
    day: 'numeric',
    month: 'short'
  });
  const timeText = date.toLocaleTimeString('en-IN', {
    hour: 'numeric',
    minute: '2-digit',
    hour12: true
  });
  return `${dateText}, ${timeText}`;
}

/**
 * Convert raw event rows plus their related records into the shape used by Huddl.
 * @param {Array<Record<string, any>>} eventRows
 * @param {string} userId
 * @returns {Promise<HuddlEvent[]>}
 */
async function hydrateEvents(eventRows, userId) {
  if (!eventRows?.length) return [];

  const eventIds = eventRows.map((row) => row.id);
  const hostIds = [...new Set(eventRows.map((row) => row.host_id))];

  const [sportResult, esportsResult, memberResult, requestResult, hostResult] = await Promise.all([
    supabase.from('event_sports').select('event_id, sport_id, skill_level_code').in('event_id', eventIds),
    supabase.from('event_esports').select('event_id, game_id, platform, game_mode, skill_level_code').in('event_id', eventIds),
    supabase.from('event_members').select('event_id, user_id, role').in('event_id', eventIds),
    supabase.from('event_join_requests').select('id, event_id, user_id, status').eq('status', 'pending').in('event_id', eventIds),
    supabase.from('profiles').select('id, display_name, handle').in('id', hostIds)
  ]);

  const firstError = sportResult.error ?? esportsResult.error ?? memberResult.error ?? requestResult.error ?? hostResult.error;
  if (firstError) {
    console.error('Event hydration details failed; keeping base events visible:', firstError);
    return eventRows.map((row) => ({
      id: row.id,
      eventType: row.event_type_code === 'esports' ? 'esports' : 'sport',
      sport: row.event_type_code === 'esports' ? 'Esports' : 'Sport',
      title: row.title,
      startsAt: row.starts_at,
      date: displayDateTimeFromTimestamp(row.starts_at),
      dateValue: dateValueFromTimestamp(row.starts_at),
      time: timeValueFromTimestamp(row.starts_at),
      location: row.location_name ?? 'Location not set',
      host: 'Player',
      hostId: row.host_id,
      members: 0,
      capacity: row.capacity,
      skill: 'Intermediate',
      color: row.event_type_code === 'esports' ? 'esports' : 'mint',
      description: row.description ?? 'A new Huddl event.',
      visibility: row.visibility === 'private' ? 'Private' : 'Public',
      status: row.status,
      pendingRequests: 0,
      pendingRequestId: null,
      isMember: row.host_id === userId,
      ratingsSubmitted: Boolean(row.host_rated_at),
      platform: null,
      gameMode: null,
      memberProfiles: []
    }));
  }

  const sportRows = sportResult.data ?? [];
  const esportsRows = esportsResult.data ?? [];
  const memberRows = memberResult.data ?? [];
  const requestRows = requestResult.data ?? [];

  const sportIds = [...new Set(sportRows.map((row) => row.sport_id))];
  const skillCodes = [...new Set([...sportRows.map((row) => row.skill_level_code), ...esportsRows.map((row) => row.skill_level_code)].filter(Boolean))];
  const gameIds = [...new Set(esportsRows.map((row) => row.game_id))];
  const memberIds = [...new Set(memberRows.map((row) => row.user_id))];

  const [sportsResult, skillsResult, gamesResult, memberProfilesResult] = await Promise.all([
    sportIds.length ? supabase.from('sports').select('id, name').in('id', sportIds) : Promise.resolve({ data: [], error: null }),
    skillCodes.length ? supabase.from('skill_levels').select('code, name').in('code', skillCodes) : Promise.resolve({ data: [], error: null }),
    gameIds.length ? supabase.from('esports_games').select('id, name, platform').in('id', gameIds) : Promise.resolve({ data: [], error: null }),
    memberIds.length ? supabase.from('profiles').select('id, display_name, handle').in('id', memberIds) : Promise.resolve({ data: [], error: null })
  ]);
  const lookupError = sportsResult.error ?? skillsResult.error ?? gamesResult.error ?? memberProfilesResult.error;
  if (lookupError) {
    console.error('Event catalog hydration failed; keeping base events visible:', lookupError);
  }

  const sportByEvent = new Map(sportRows.map((row) => [row.event_id, row]));
  const esportsByEvent = new Map(esportsRows.map((row) => [row.event_id, row]));
  const sportNameById = new Map((sportsResult.data ?? []).map((row) => [row.id, row.name]));
  const skillNameByCode = new Map((skillsResult.data ?? []).map((row) => [row.code, row.name]));
  const gameById = new Map((gamesResult.data ?? []).map((row) => [row.id, row]));
  const hostNameById = new Map((hostResult.data ?? []).map((row) => [row.id, row.display_name]));
  const profileById = new Map((memberProfilesResult.data ?? []).map((row) => [row.id, row]));

  /** @type {Map<string, EventMemberRow[]>} */
  const membersByEvent = new Map();
  for (const row of memberRows) {
    const current = membersByEvent.get(row.event_id) ?? [];
    current.push(row);
    membersByEvent.set(row.event_id, current);
  }

  /** @type {Map<string, EventRequestRow[]>} */
  const requestsByEvent = new Map();
  for (const row of requestRows) {
    const current = requestsByEvent.get(row.event_id) ?? [];
    current.push(row);
    requestsByEvent.set(row.event_id, current);
  }

  return eventRows.flatMap((row) => {
    const isEsports = row.event_type_code === 'esports';
    const sportRow = sportByEvent.get(row.id);
    const esportsRow = esportsByEvent.get(row.id);
    const game = esportsRow ? gameById.get(esportsRow.game_id) : undefined;
    const label = isEsports
      ? game?.name ?? 'Esports'
      : sportRow
        ? sportNameById.get(sportRow.sport_id) ?? 'Sport'
        : 'Sport';

    const members = membersByEvent.get(row.id) ?? [];
    const pendingRequests = requestsByEvent.get(row.id) ?? [];
    const host = hostNameById.get(row.host_id) ?? 'Player';
    const memberProfiles = members.map(/** @param {EventMemberRow} member */ (member) => {
      const profile = profileById.get(member.user_id);
      return {
        id: member.user_id,
        name: profile?.display_name ?? 'Player',
        handle: profile?.handle ?? '',
        color: colorForId(member.user_id)
      };
    });

    return [{
      id: row.id,
      eventType: isEsports ? 'esports' : 'sport',
      sport: label,
      gameId: game?.id,
      title: row.title,
      startsAt: row.starts_at,
      date: displayDateTimeFromTimestamp(row.starts_at),
      dateValue: dateValueFromTimestamp(row.starts_at),
      time: timeValueFromTimestamp(row.starts_at),
      location: row.location_name ?? 'Location not set',
      host,
      hostId: row.host_id,
      members: members.length,
      capacity: row.capacity,
      skill: skillNameByCode.get((isEsports ? esportsRow?.skill_level_code : sportRow?.skill_level_code) ?? '') ?? 'Intermediate',
      color: isEsports ? 'esports' : colorForSport(label),
      description: row.description ?? 'A new Huddl event.',
      visibility: row.visibility === 'private' ? 'Private' : 'Public',
      status: row.status,
      pendingRequests: pendingRequests.filter(/** @param {EventRequestRow} request */ (request) => request.user_id !== userId).length,
      pendingRequestId: pendingRequests.find(/** @param {EventRequestRow} request */ (request) => request.user_id !== userId)?.id ?? null,
      isMember: members.some(/** @param {EventMemberRow} member */ (member) => member.user_id === userId),
      ratingsSubmitted: Boolean(row.host_rated_at),
      platform: isEsports ? (esportsRow?.platform ?? game?.platform ?? null) : null,
      gameMode: isEsports ? esportsRow?.game_mode ?? null : null,
      memberProfiles
    }];
  });
}

/**
 * Load discoverable upcoming events for the Home feed.
 * @param {string} userId
 * @returns {Promise<HuddlEvent[]>}
 */
export async function loadSportEvents(userId) {
  const { data: eventRows, error: eventError } = await supabase
    .from('events')
    .select('id, event_type_code, host_id, title, description, starts_at, location_name, capacity, visibility, status, host_rated_at')
    .in('event_type_code', ['sport', 'esports'])
    .in('status', ['upcoming', 'full'])
    .gt('starts_at', new Date().toISOString())
    .order('starts_at', { ascending: true })
    .limit(100);

  if (eventError) throw eventError;
  return hydrateEvents(eventRows ?? [], userId);
}

/**
 * Load every event the current user has hosted or joined, including completed and cancelled games.
 * This deliberately uses the user's own host/member IDs rather than the Home feed query,
 * so historical and private games are not dropped just because they are no longer discoverable.
 * @param {string} userId
 * @returns {Promise<HuddlEvent[]>}
 */
export async function loadUserEvents(userId) {
  const [hostResult, memberResult] = await Promise.all([
    supabase.from('events').select('id').eq('host_id', userId),
    supabase.from('event_members').select('event_id').eq('user_id', userId)
  ]);

  if (hostResult.error) throw hostResult.error;
  if (memberResult.error) throw memberResult.error;

  const eventIds = [...new Set([
    ...(hostResult.data ?? []).map((row) => row.id),
    ...(memberResult.data ?? []).map((row) => row.event_id)
  ])];

  if (!eventIds.length) return [];

  const { data: eventRows, error: eventError } = await supabase
    .from('events')
    .select('id, event_type_code, host_id, title, description, starts_at, location_name, capacity, visibility, status, host_rated_at')
    .in('id', eventIds)
    .in('event_type_code', ['sport', 'esports'])
    .order('starts_at', { ascending: false });

  if (eventError) throw eventError;
  return hydrateEvents(eventRows ?? [], userId);
}

/** @param {{title:string,description:string,dateValue:string,time:string,location:string,capacity:number|string,visibility:string,sport:string,skill:string}} form */
export async function createSportEvent(form) {
  const [{ data: sportRow, error: sportError }, { data: skillRow, error: skillError }] = await Promise.all([
    supabase.from('sports').select('id').eq('name', form.sport).maybeSingle(),
    supabase.from('skill_levels').select('code').eq('name', form.skill).maybeSingle()
  ]);

  if (sportError) throw sportError;
  if (skillError) throw skillError;
  if (!sportRow?.id) throw new Error('Selected sport is unavailable.');
  if (!skillRow?.code) throw new Error('Selected skill level is unavailable.');

  const startsAt = new Date(`${form.dateValue}T${form.time}:00`).toISOString();
  const { data: eventId, error } = await supabase.rpc('create_sport_event', {
    p_title: form.title.trim(),
    p_description: form.description?.trim() || null,
    p_starts_at: startsAt,
    p_location_name: form.location.trim(),
    p_capacity: Number(form.capacity),
    p_visibility: form.visibility === 'Private' ? 'private' : 'public',
    p_sport_id: sportRow.id,
    p_skill_level_code: skillRow.code
  });

  if (error) throw error;
  return eventId;
}


/** @param {{title:string,description:string,dateValue:string,time:string,location:string,capacity:number|string,visibility:string,gameId:string,platform:string,gameMode:string,skill:string}} form */
export async function createEsportsEvent(form) {
  const [{ data: gameRow, error: gameError }, { data: skillRow, error: skillError }] = await Promise.all([
    supabase
      .from('esports_games')
      .select('id, platform')
      .eq('id', form.gameId)
      .eq('enabled', true)
      .maybeSingle(),
    supabase
      .from('skill_levels')
      .select('code')
      .eq('name', form.skill)
      .maybeSingle()
  ]);

  if (gameError) throw gameError;
  if (skillError) throw skillError;
  if (!gameRow?.id) throw new Error('Selected esports game is unavailable.');
  if (!skillRow?.code) throw new Error('Selected skill level is unavailable.');

  const startsAt = new Date(`${form.dateValue}T${form.time}:00`).toISOString();
  const { data: eventId, error } = await supabase.rpc('create_esports_event', {
    p_title: form.title.trim(),
    p_description: form.description?.trim() || null,
    p_starts_at: startsAt,
    p_location_name: form.location.trim(),
    p_capacity: Number(form.capacity),
    p_visibility: form.visibility === 'Private' ? 'private' : 'public',
    p_game_id: gameRow.id,
    p_platform: form.platform?.trim() || gameRow.platform || null,
    p_game_mode: form.gameMode?.trim() || null,
    p_skill_level_code: skillRow.code
  });

  if (error) throw error;
  return eventId;
}

/** @param {string} eventId */
export async function joinPublicEvent(eventId) {
  const { data, error } = await supabase.rpc('join_event', { p_event_id: eventId });
  if (error) throw error;
  return data;
}

/** @param {string} eventId */
export async function requestPrivateEvent(eventId) {
  const { data, error } = await supabase.rpc('request_event_join', {
    p_event_id: eventId
  });
  if (error) throw error;
  return data;
}

/** @param {string} eventId */
export async function leaveEvent(eventId) {
  const { data, error } = await supabase.rpc('leave_event', { p_event_id: eventId });
  if (error) throw error;
  return data;
}

/** @param {string} eventId @param {{title:string,description:string,dateValue:string,time:string,location:string,capacity:number|string,visibility:string,sport:string,skill:string}} form */
export async function updateSportEvent(eventId, form) {
  const [{ data: sportRow, error: sportError }, { data: skillRow, error: skillError }] = await Promise.all([
    supabase.from('sports').select('id').eq('name', form.sport).maybeSingle(),
    supabase.from('skill_levels').select('code').eq('name', form.skill).maybeSingle()
  ]);

  if (sportError) throw sportError;
  if (skillError) throw skillError;
  if (!sportRow?.id) throw new Error('Selected sport is unavailable.');
  if (!skillRow?.code) throw new Error('Selected skill level is unavailable.');

  const startsAt = new Date(`${form.dateValue}T${form.time}:00`).toISOString();
  const { error: eventError } = await supabase
    .from('events')
    .update({
      title: form.title.trim(),
      description: form.description?.trim() || null,
      starts_at: startsAt,
      location_name: form.location.trim(),
      capacity: Number(form.capacity),
      visibility: form.visibility === 'Private' ? 'private' : 'public'
    })
    .eq('id', eventId);

  if (eventError) throw eventError;

  const { error: sportUpdateError } = await supabase
    .from('event_sports')
    .upsert(
      {
        event_id: eventId,
        sport_id: sportRow.id,
        skill_level_code: skillRow.code
      },
      { onConflict: 'event_id' }
    );

  if (sportUpdateError) throw sportUpdateError;
}


/** @param {string} eventId @param {{title:string,description:string,dateValue:string,time:string,location:string,capacity:number|string,visibility:string,gameId:string,platform:string,gameMode:string,skill:string}} form */
export async function updateEsportsEvent(eventId, form) {
  const [{ data: gameRow, error: gameError }, { data: skillRow, error: skillError }] = await Promise.all([
    supabase
      .from('esports_games')
      .select('id, platform')
      .eq('id', form.gameId)
      .eq('enabled', true)
      .maybeSingle(),
    supabase
      .from('skill_levels')
      .select('code')
      .eq('name', form.skill)
      .maybeSingle()
  ]);
  if (gameError) throw gameError;
  if (skillError) throw skillError;
  if (!gameRow?.id) throw new Error('Selected esports game is unavailable.');
  if (!skillRow?.code) throw new Error('Selected skill level is unavailable.');

  const startsAt = new Date(`${form.dateValue}T${form.time}:00`).toISOString();
  const { error: eventError } = await supabase
    .from('events')
    .update({
      title: form.title.trim(),
      description: form.description?.trim() || null,
      starts_at: startsAt,
      location_name: form.location.trim(),
      capacity: Number(form.capacity),
      visibility: form.visibility === 'Private' ? 'private' : 'public'
    })
    .eq('id', eventId);
  if (eventError) throw eventError;

  const { error: esportsError } = await supabase
    .from('event_esports')
    .upsert({
      event_id: eventId,
      game_id: gameRow.id,
      platform: form.platform?.trim() || gameRow.platform || null,
      game_mode: form.gameMode?.trim() || null,
      skill_level_code: skillRow.code
    }, { onConflict: 'event_id' });
  if (esportsError) throw esportsError;
}

/** @param {string} eventId @param {'completed'|'cancelled'} status */
export async function setEventStatus(eventId, status) {
  if (status === 'completed') {
    const { data, error } = await supabase.rpc('complete_event', {
      p_event_id: eventId
    });
    if (error) throw error;
    return data;
  }

  const { error } = await supabase
    .from('events')
    .update({ status })
    .eq('id', eventId);

  if (error) throw error;
  return status;
}

/** @param {string} requestId @param {boolean} accept */
export async function decideEventJoinRequest(requestId, accept) {
  const { data, error } = await supabase.rpc('decide_event_join_request', {
    p_request_id: requestId,
    p_accept: accept
  });
  if (error) throw error;
  return data;
}
