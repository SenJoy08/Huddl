import { supabase } from '$lib/supabase/client.js';

/**
 * @typedef {{
 *   name: string,
 *   handle: string,
 *   bio: string,
 *   sports: string[],
 *   skills: string[],
 *   phone: string,
 *   settings: {
 *     showContact: boolean,
 *     eventNotifications: boolean,
 *     friendNotifications: boolean,
 *     ratingNotifications: boolean
 *   }
 * }} UserProfile
 */

export const DEFAULT_PROFILE = {
  name: 'Player',
  handle: '@player',
  bio: 'Always down for a game.',
  sports: [],
  skills: [],
  phone: '',
  settings: {
    showContact: false,
    eventNotifications: true,
    friendNotifications: true,
    ratingNotifications: true
  }
};

/**
 * Load only the public-facing fields for another player's profile.
 * Contact information and notification settings intentionally stay out of
 * this function so callers cannot accidentally treat private profile data as
 * public profile data.
 * @param {string} userId
 * @returns {Promise<{name:string,handle:string,bio:string,sports:string[],skills:string[],phone?:string}|null>}
 */
export async function loadPublicProfile(userId) {
  const [profileResult, sportsResult, contactResult] = await Promise.all([
    supabase
      .from('profiles')
      .select('display_name, handle, bio')
      .eq('id', userId)
      .maybeSingle(),
    supabase
      .from('profile_sports')
      .select('sport_id, skill_level_code')
      .eq('profile_id', userId),
    supabase.rpc('get_visible_profile_contact', { target_user: userId })
  ]);

  const firstError = profileResult.error ?? sportsResult.error ?? contactResult.error;
  if (firstError) throw firstError;
  if (!profileResult.data) return null;

  const profileSports = sportsResult.data ?? [];
  const sportIds = [...new Set(profileSports.map((row) => row.sport_id))];
  const skillCodes = [...new Set(profileSports.map((row) => row.skill_level_code))];

  /** @type {{ id: string, name: string }[]} */
  let sportRows = [];
  /** @type {{ code: string, name: string }[]} */
  let skillRows = [];

  if (sportIds.length) {
    const { data, error } = await supabase.from('sports').select('id, name').in('id', sportIds);
    if (error) throw error;
    sportRows = data ?? [];
  }

  if (skillCodes.length) {
    const { data, error } = await supabase.from('skill_levels').select('code, name').in('code', skillCodes);
    if (error) throw error;
    skillRows = data ?? [];
  }

  const sportNameById = new Map(sportRows.map((row) => [row.id, row.name]));
  const skillNameByCode = new Map(skillRows.map((row) => [row.code, row.name]));
  const sports = [];
  const skills = [];

  for (const row of profileSports) {
    const sportName = sportNameById.get(row.sport_id);
    if (!sportName) continue;
    sports.push(sportName);
    skills.push(skillNameByCode.get(row.skill_level_code) ?? 'Intermediate');
  }

  return {
    name: profileResult.data.display_name ?? 'Player',
    handle: profileResult.data.handle ?? '@player',
    bio: profileResult.data.bio ?? 'Always down for a game.',
    sports,
    skills,
    phone: contactResult.data ?? ''
  };
}

/** @param {string} userId @returns {Promise<UserProfile | null>} */
export async function loadUserProfile(userId) {
  const [profileResult, sportsResult, preferencesResult, contactResult] = await Promise.all([
    supabase
      .from('profiles')
      .select('display_name, handle, bio')
      .eq('id', userId)
      .maybeSingle(),
    supabase
      .from('profile_sports')
      .select('sport_id, skill_level_code')
      .eq('profile_id', userId),
    supabase
      .from('notification_preferences')
      .select('event_updates, friend_updates, rating_reminders')
      .eq('user_id', userId)
      .maybeSingle(),
    supabase.rpc('get_own_contact_profile')
  ]);

  const firstError = profileResult.error ?? sportsResult.error ?? preferencesResult.error ?? contactResult.error;
  if (firstError) throw firstError;
  if (!profileResult.data) return null;

  const profileSports = sportsResult.data ?? [];
  const sportIds = profileSports.map((row) => row.sport_id);
  const skillCodes = profileSports.map((row) => row.skill_level_code);

  /** @type {{ id: string, name: string }[]} */
  let sportRows = [];
  /** @type {{ code: string, name: string }[]} */
  let skillRows = [];

  if (sportIds.length) {
    const { data, error } = await supabase.from('sports').select('id, name').in('id', sportIds);
    if (error) throw error;
    sportRows = data ?? [];
  }

  if (skillCodes.length) {
    const { data, error } = await supabase.from('skill_levels').select('code, name').in('code', skillCodes);
    if (error) throw error;
    skillRows = data ?? [];
  }

  const sportNameById = new Map(sportRows.map((row) => [row.id, row.name]));
  const skillNameByCode = new Map(skillRows.map((row) => [row.code, row.name]));
  const sportNames = [];
  const skillNames = [];

  for (const row of profileSports) {
    const sportName = sportNameById.get(row.sport_id);
    if (!sportName) continue;
    sportNames.push(sportName);
    skillNames.push(skillNameByCode.get(row.skill_level_code) ?? 'Intermediate');
  }

  const notificationPreferences = preferencesResult.data;
  return {
    name: profileResult.data.display_name ?? 'Player',
    handle: profileResult.data.handle ?? '@player',
    bio: profileResult.data.bio ?? 'Always down for a game.',
    sports: sportNames,
    skills: skillNames,
    phone: contactResult.data?.phone ?? '',
    settings: {
      showContact: contactResult.data?.contact_visibility !== 'nobody',
      eventNotifications: notificationPreferences?.event_updates ?? true,
      friendNotifications: notificationPreferences?.friend_updates ?? true,
      ratingNotifications: notificationPreferences?.rating_reminders ?? true
    }
  };
}

/** @param {string} userId @param {{name:string,handle:string,bio:string}} values */
export async function saveProfileBasics(userId, values) {
  const handle = values.handle.trim();

  if (handle) {
    const { data: conflictingProfile, error: handleLookupError } = await supabase
      .from('profiles')
      .select('id')
      .eq('handle', handle)
      .neq('id', userId)
      .maybeSingle();

    if (handleLookupError) return { error: handleLookupError };
    if (conflictingProfile) return { error: new Error('That handle is already taken.') };
  }

  const { error } = await supabase
    .from('profiles')
    .update({
      display_name: values.name,
      handle,
      bio: values.bio
    })
    .eq('id', userId);

  return { error };
}

/** @param {string} userId @param {string[]} sports @param {Record<string,string>} skills */
export async function saveProfileSports(userId, sports, skills) {
  const { data: sportRows, error: sportError } = await supabase
    .from('sports')
    .select('id, name')
    .in('name', sports);
  if (sportError) return { error: sportError };

  const skillNames = sports.map((sport) => skills[sport] ?? 'Intermediate');
  const { data: skillRows, error: skillError } = await supabase
    .from('skill_levels')
    .select('code, name')
    .in('name', skillNames);
  if (skillError) return { error: skillError };

  const sportIdByName = new Map((sportRows ?? []).map((row) => [row.name, row.id]));
  const skillCodeByName = new Map((skillRows ?? []).map((row) => [row.name, row.code]));
  const rows = sports.map((sport) => ({
    profile_id: userId,
    sport_id: sportIdByName.get(sport),
    skill_level_code: skillCodeByName.get(skills[sport] ?? 'Intermediate')
  }));

  if (rows.some((row) => !row.sport_id || !row.skill_level_code)) {
    return { error: new Error('Could not match one or more sports or skill levels.') };
  }

  const { error: deleteError } = await supabase
    .from('profile_sports')
    .delete()
    .eq('profile_id', userId);
  if (deleteError) return { error: deleteError };

  const { error: insertError } = await supabase.from('profile_sports').insert(rows);
  return { error: insertError };
}

/** @param {string} userId @param {{eventNotifications:boolean,friendNotifications:boolean,ratingNotifications:boolean}} values */
export async function saveNotificationPreferences(userId, values) {
  const { error } = await supabase
    .from('notification_preferences')
    .upsert(
      {
        user_id: userId,
        event_updates: values.eventNotifications,
        friend_updates: values.friendNotifications,
        rating_reminders: values.ratingNotifications
      },
      { onConflict: 'user_id' }
    );
  return { error };
}

/** @param {string} userId @param {{phone?:string,contactVisible?:boolean}} values */
export async function saveAccountProfile(userId, values) {
  const payload = {
    ...(values.phone !== undefined ? { phone: values.phone } : {}),
    ...(values.contactVisible !== undefined
      ? { contact_visibility: values.contactVisible ? 'friends' : 'nobody' }
      : {})
  };
  const { error } = await supabase.from('profiles').update(payload).eq('id', userId);
  return error;
}
