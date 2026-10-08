import { supabase } from '$lib/supabase/client.js';

/** @typedef {{ id: string, slug: string, name: string, platform?: string | null }} EsportsGame */

/** @returns {Promise<EsportsGame[]>} */
export async function loadEsportsGames() {
  const { data, error } = await supabase
    .from('esports_games')
    .select('id, slug, name, platform')
    .eq('enabled', true)
    .order('name', { ascending: true });
  if (error) throw error;
  return data ?? [];
}
