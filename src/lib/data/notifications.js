import { supabase } from '$lib/supabase/client.js';

/** @typedef {{ id: string, type: string, eventId?: string | null, friendRequestId?: string | null, message: string, time: string, createdAt: string, unread: boolean }} HuddlNotification */

/** @type {Record<string, string>} */
const TITLE_BY_TYPE = {
  friend_request_received: 'Friend request',
  friend_request_accepted: 'Friend request accepted',
  friend_request_declined: 'Friend request declined',
  event_join_request_received: 'Event join request',
  event_join_request_accepted: 'Join request accepted',
  event_join_request_declined: 'Join request declined',
  event_member_joined: 'Player joined your event',
  event_updated: 'Event updated',
  event_cancelled: 'Event cancelled',
  rating_reminder: 'Rating reminder'
};

/** @param {string} type */
function titleForType(type) {
  return TITLE_BY_TYPE[type] ?? 'Huddl update';
}

/** @param {string} value */
function relativeTime(value) {
  const created = new Date(value).getTime();
  if (!Number.isFinite(created)) return '';

  const seconds = Math.max(0, Math.floor((Date.now() - created) / 1000));
  if (seconds < 60) return 'just now';
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
  if (seconds < 604800) return `${Math.floor(seconds / 86400)}d ago`;

  return new Date(value).toLocaleDateString('en-IN', {
    day: 'numeric',
    month: 'short',
    year: new Date(value).getFullYear() !== new Date().getFullYear() ? 'numeric' : undefined
  });
}

/** @param {Record<string, unknown>} row @returns {HuddlNotification & { title: string }} */
function shapeNotification(row) {
  const createdAt = String(row.created_at ?? '');
  const type = String(row.type ?? '');
  return {
    id: String(row.id),
    type,
    title: titleForType(type),
    eventId: row.event_id ? String(row.event_id) : null,
    friendRequestId: row.friend_request_id ? String(row.friend_request_id) : null,
    message: String(row.message ?? 'Huddl has an update for you.'),
    time: relativeTime(createdAt),
    createdAt,
    unread: !Boolean(row.read)
  };
}

/** @param {string} userId @returns {Promise<(HuddlNotification & { title: string })[]>} */
export async function loadNotifications(userId) {
  if (!userId) return [];

  const { data, error } = await supabase
    .from('notifications')
    .select('id, recipient_id, actor_id, type, event_id, friend_request_id, message, read, created_at')
    .eq('recipient_id', userId)
    .eq('read', false)
    .order('created_at', { ascending: false })
    .limit(50);

  if (error) throw error;
  return (data ?? []).map(shapeNotification);
}

/** @param {string} notificationId */
export async function markNotificationRead(notificationId) {
  if (!notificationId) return;

  const { error } = await supabase
    .from('notifications')
    .update({ read: true })
    .eq('id', notificationId);

  if (error) throw error;
}

/** Mark every notification belonging to the authenticated user as read. */
export async function markAllNotificationsRead() {
  const { error } = await supabase
    .from('notifications')
    .update({ read: true })
    .eq('recipient_id', (await supabase.auth.getUser()).data.user?.id ?? '00000000-0000-0000-0000-000000000000')
    .eq('read', false);

  if (error) throw error;
}

/**
 * Subscribe to newly-created notifications for one user.
 * @param {string} userId
 * @param {(notification: HuddlNotification & { title: string }) => void} onNotification
 * @returns {() => void}
 */
export function subscribeToNotifications(userId, onNotification) {
  if (!userId) return () => {};

  const channel = supabase
    .channel(`huddl-notifications:${userId}`)
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'notifications',
        filter: `recipient_id=eq.${userId}`
      },
      /** @param {{ new: Record<string, unknown> }} payload */
      (payload) => {
        onNotification(shapeNotification(payload.new));
      }
    )
    .on(
      'postgres_changes',
      {
        event: 'UPDATE',
        schema: 'public',
        table: 'notifications',
        filter: `recipient_id=eq.${userId}`
      },
      /** @param {{ new: Record<string, unknown> }} payload */
      (payload) => {
        onNotification(shapeNotification(payload.new));
      }
    )
    .subscribe(/** @param {string} status */ (status) => {
      if (status === 'CHANNEL_ERROR') {
        console.error('Notifications realtime channel failed.');
      }
    });

  return () => {
    void supabase.removeChannel(channel);
  };
}
