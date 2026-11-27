/** @param {unknown} value */
function firstRelation(value) {
  return Array.isArray(value) ? value[0] ?? null : value ?? null;
}

/**
 * Normalize PostgREST's to-one embedded relation shape. Depending on the
 * generated schema and relationship metadata it may be an object or array.
 * @param {Array<Record<string, any>>} rows
 * @returns {{ selected: string[], skills: Record<string, string> }}
 */
export function mapProfileSports(rows) {
  /** @type {string[]} */
  const selected = [];
  /** @type {Record<string, string>} */
  const skills = {};

  for (const row of rows ?? []) {
    const sport = firstRelation(row.sports);
    const skill = firstRelation(row.skill_levels);
    /** @type {string} */
    const name = typeof sport?.name === 'string' ? sport.name : '';
    if (!name) continue;
    selected.push(name);
    skills[name] = typeof skill?.name === 'string' ? skill.name : 'Intermediate';
  }

  return { selected, skills };
}
