import { supabase } from '$lib/supabase/client.js';

/**
 * Generic Postgres Changes payload used by Huddl subscriptions.
 * @typedef {Object} HuddlRealtimePayload
 * @property {Record<string, unknown>} [new]
 * @property {Record<string, unknown>} [old]
 */

/**
 * Callbacks used by Huddl's shared realtime subscription.
 * @typedef {Object} HuddlRealtimeCallbacks
 * @property {(payload: HuddlRealtimePayload) => void} [onEventsChange]
 * @property {(payload: HuddlRealtimePayload) => void} [onFriendsChange]
 * @property {(status: string, error?: unknown) => void} [onStatus]
 */

/**
 * Subscribe to the database changes that affect the current Huddl user's UI.
 * Postgres Changes is intentionally used here because Huddl is still at a
 * relatively small scale and it requires much less infrastructure than a
 * Broadcast-based architecture.
 * @param {string} userId
 * @param {HuddlRealtimeCallbacks} [callbacks]
 * @returns {() => void}
 */
export function subscribeToHuddlRealtime(userId, callbacks = {}) {
  if (!userId) return () => {};

  const channel = supabase.channel(`huddl-live:${userId}`);
  /** @param {HuddlRealtimePayload} payload */
  const eventHandler = (payload) => callbacks.onEventsChange?.(payload);
  /** @param {HuddlRealtimePayload} payload */
  const friendHandler = (payload) => callbacks.onFriendsChange?.(payload);

  channel
    .on('postgres_changes', { event: '*', schema: 'public', table: 'events' }, eventHandler)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'event_sports' }, eventHandler)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'event_members' }, eventHandler)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'event_join_requests' }, eventHandler)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'friend_requests' }, friendHandler)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'friendships' }, friendHandler)
    .subscribe(/** @param {string} status @param {unknown} error */ (status, error) => {
      callbacks.onStatus?.(status, error);
    });

  return () => {
    void supabase.removeChannel(channel);
  };
}


/**
 * Subscribe to messages for one open event chat.
 *
 * @param {string} eventId
 * @param {(payload: HuddlRealtimePayload) => void} onMessage
 * @param {(status: string, error?: unknown) => void} [onStatus]
 * @returns {() => void}
 */
export function subscribeToEventMessages(eventId, onMessage, onStatus) {
  if (!eventId) return () => {};

  const channel = supabase
    .channel(`huddl-chat:${eventId}`)
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'event_messages'
      },
      (payload) => {
        if (String(payload.new?.event_id ?? '') === String(eventId)) {
          onMessage(payload);
        }
      }
    )
    .on(
      'postgres_changes',
      {
        event: 'UPDATE',
        schema: 'public',
        table: 'event_messages'
      },
      (payload) => {
        if (String(payload.new?.event_id ?? payload.old?.event_id ?? '') === String(eventId)) {
          onMessage(payload);
        }
      }
    )
    .subscribe(/** @param {string} status @param {unknown} error */ (status, error) => {
      onStatus?.(status, error);
    });

  return () => {
    void supabase.removeChannel(channel);
  };
}
