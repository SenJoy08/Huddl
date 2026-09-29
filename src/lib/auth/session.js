const SESSION_KEY = 'huddle.mock.session';
const PROFILE_KEY = 'huddle.mock.profile';

/** @typedef {{ id: string, name: string, email: string }} MockUser */

/** @returns {MockUser | null} */
export function getSession() {
  if (typeof localStorage === 'undefined') return null;
  try {
    const raw = localStorage.getItem(SESSION_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

/** @param {MockUser} user */
export function setSession(user) {
  localStorage.setItem(SESSION_KEY, JSON.stringify(user));
}

export function clearSession() {
  localStorage.removeItem(SESSION_KEY);
}

/** @returns {Record<string, any> | null} */
export function getProfile() {
  if (typeof localStorage === 'undefined') return null;
  try {
    const raw = localStorage.getItem(PROFILE_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

/** @param {Record<string, any>} profile */
export function setProfile(profile) {
  localStorage.setItem(PROFILE_KEY, JSON.stringify(profile));
}
