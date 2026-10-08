import { supabase } from "$lib/supabase/client.js";

/**
 * Get the current Supabase auth session.
 * @returns {Promise<import('@supabase/supabase-js').Session | null>}
 */
export async function getSession() {
  const {
    data: { session },
    error,
  } = await supabase.auth.getSession();

  if (error) {
    console.error("Failed to get session:", error);
    return null;
  }

  return session;
}

/**
 * Sign up a user.
 * @param {string} email
 * @param {string} password
 * @param {object} [options]
 * @returns {Promise<import('@supabase/supabase-js').AuthResponse>}
 */
export async function signUp(email, password, options = {}) {
  return await supabase.auth.signUp({
    email,
    password,
    options,
  });
}

/**
 * Sign in a user.
 * @param {string} email
 * @param {string} password
 * @returns {Promise<import('@supabase/supabase-js').AuthResponse>}
 */
export async function signIn(email, password) {
  return await supabase.auth.signInWithPassword({
    email,
    password,
  });
}

/**
 * Sign out the current user.
 * @returns {Promise<{ error: import('@supabase/supabase-js').AuthError | null }>}
 */
export async function signOut() {
  return await supabase.auth.signOut();
}

/**
 * Send a password reset email.
 * @param {string} email
 */
export async function resetPassword(email) {
  const { data, error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo:
      typeof window !== "undefined"
        ? `${window.location.origin}/reset-password`
        : undefined,
  });

  return { data, error };
}

/**
 * Set a new password for the currently authenticated user.
 * @param {string} password

 */
export async function updatePassword(password) {
  return await supabase.auth.updateUser({ password });
}

/**
 * Listen for auth state changes.
 * @param {(event: import('@supabase/supabase-js').AuthChangeEvent, session: import('@supabase/supabase-js').Session | null) => void} callback
 */
export function onAuthStateChange(callback) {
  return supabase.auth.onAuthStateChange(callback);
}
