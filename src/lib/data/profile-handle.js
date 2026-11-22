/** Normalize the existing @handle format to lowercase and enforce its bounds. @param {string} value */
export function normalizeProfileHandle(value) {
  const base = String(value ?? '').trim().replace(/^@/, '').toLowerCase();
  const handle = `@${base}`;
  if (!/^@[a-z0-9_]{2,18}$/.test(handle)) {
    throw new Error('Use 2-18 letters, numbers or underscores after @.');
  }
  return handle;
}
