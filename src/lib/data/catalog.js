import { supabase } from '$lib/supabase/client.js';

/** @returns {Promise<{sports: string[], skillLevels: string[]}>} */
export async function loadGameCatalog() {
  const [sportsResult, skillsResult] = await Promise.all([
    supabase
      .from('sports')
      .select('name')
      .eq('enabled', true)
      .order('name', { ascending: true }),
    supabase
      .from('skill_levels')
      .select('name')
      .order('sort_order', { ascending: true })
  ]);

  const firstError = sportsResult.error ?? skillsResult.error;
  if (firstError) throw firstError;

  return {
    sports: ['All', ...(sportsResult.data ?? []).map((row) => String(row.name)).filter(Boolean)],
    skillLevels: (skillsResult.data ?? []).map((row) => String(row.name)).filter(Boolean)
  };
}
