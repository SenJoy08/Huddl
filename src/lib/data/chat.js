import { supabase } from '$lib/supabase/client.js';

/** @typedef {{ id: string, eventId: string, senderId: string, sender: string, text: string, time: string, createdAt: string, mine: boolean }} HuddlChatMessage */

/** @param {string} value */
function formatTime(value) {
  const date = new Date(value);
  if (!Number.isFinite(date.getTime())) return '';
  return date.toLocaleTimeString('en-IN', { hour: 'numeric', minute: '2-digit' });
}

/** @param {Record<string, unknown>} row @param {Record<string, string>} names @param {string} userId @returns {HuddlChatMessage} */
function shapeMessage(row, names, userId) {
  const createdAt = String(row.created_at ?? '');
  const senderId = String(row.sender_id ?? '');
  return {
    id: String(row.id),
    eventId: String(row.event_id),
    senderId,
    sender: names[senderId] ?? (senderId === userId ? 'You' : 'Player'),
    text: String(row.body ?? ''),
    time: formatTime(createdAt),
    createdAt,
    mine: senderId === userId
  };
}

/** @param {string} eventId @param {string} userId @returns {Promise<HuddlChatMessage[]>} */
export async function loadEventMessages(eventId, userId) {
  if (!eventId || !userId) return [];

  const { data, error } = await supabase
    .from('event_messages')
    .select('id, event_id, sender_id, body, created_at, edited_at, deleted_at')
    .eq('event_id', eventId)
    .order('created_at', { ascending: true })
    .limit(200);

  if (error) throw error;

  const rows = data ?? [];
  const senderIds = [...new Set(rows.map(/** @param {any} row */ (row) => String(row.sender_id)).filter(Boolean))];
  /** @type {Record<string, string>} */
  const names = {};

  if (senderIds.length) {
    const { data: profiles, error: profileError } = await supabase
      .from('profiles')
      .select('id, display_name')
      .in('id', senderIds);

    if (profileError) throw profileError;
    for (const profile of profiles ?? []) {
      names[String(profile.id)] = String(profile.display_name ?? 'Player');
    }
  }

  return rows
    .filter(/** @param {any} row */ (row) => !row.deleted_at)
    .map(/** @param {any} row */ (row) => shapeMessage(row, names, userId));
}

/** @param {string} eventId @param {string} body @returns {Promise<string>} */
export async function sendEventMessage(eventId, body) {
  const text = String(body ?? '').trim();
  if (!eventId || !text) throw new Error('Message cannot be empty');

  const { data, error } = await supabase.rpc('send_event_message', {
    p_event_id: eventId,
    p_body: text
  });

  if (error) throw error;
  return String(data);
}
