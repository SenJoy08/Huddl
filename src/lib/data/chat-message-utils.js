/** @typedef {{ id: string, eventId: string, senderId: string, sender: string, text: string, time: string, createdAt: string, mine: boolean }} HuddlChatMessage */

/** @param {string} value */
export function formatChatTime(value) {
  const date = new Date(value);
  if (!Number.isFinite(date.getTime())) return '';
  return date.toLocaleTimeString('en-IN', { hour: 'numeric', minute: '2-digit' });
}

/** @param {Array<HuddlChatMessage>} messages @param {HuddlChatMessage} message */
export function mergeChatMessage(messages, message) {
  const byId = new Map((messages ?? []).map((item) => [item.id, item]));
  byId.set(message.id, { ...message, time: formatChatTime(message.createdAt) });
  return [...byId.values()]
    .sort((a, b) => a.createdAt.localeCompare(b.createdAt))
    .slice(-200);
}
