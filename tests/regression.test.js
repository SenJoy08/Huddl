import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import { mergeChatMessage } from '../src/lib/data/chat-message-utils.js';
import { normalizeProfileHandle } from '../src/lib/data/profile-handle.js';
import { mapProfileSports } from '../src/lib/onboarding/profile-sports.js';

test('profile handles normalize uppercase and preserve existing limits', () => {
  assert.equal(normalizeProfileHandle('  @Huddl_Player '), '@huddl_player');
  assert.throws(() => normalizeProfileHandle('@@Huddl_Player'), /2-18/);
  assert.throws(() => normalizeProfileHandle('@a'), /2-18/);
  assert.throws(() => normalizeProfileHandle('@name with spaces'), /2-18/);
  assert.throws(() => normalizeProfileHandle(`@${'a'.repeat(19)}`), /2-18/);
});

test('onboarding maps embedded sport and skill relations in either PostgREST shape', () => {
  const mapped = mapProfileSports([
    { sports: [{ name: 'Football' }], skill_levels: [{ name: 'Seasoned' }] },
    { sports: { name: 'Chess' }, skill_levels: { name: 'Beginner' } }
  ]);
  assert.deepEqual(mapped, {
    selected: ['Football', 'Chess'],
    skills: { Football: 'Seasoned', Chess: 'Beginner' }
  });
});

test('chat merge deduplicates realtime echoes, orders messages, and retains only newest 200', () => {
  const message = (id, createdAt) => ({
    id, eventId: 'event-1', senderId: 'user-1', sender: 'A', text: id,
    time: '', createdAt, mine: true
  });
  const merged = mergeChatMessage(
    [message('later', '2026-11-07T10:02:00Z'), message('same', '2026-11-07T10:01:00Z')],
    message('same', '2026-11-07T10:01:00Z')
  );
  assert.deepEqual(merged.map(({ id }) => id), ['same', 'later']);
  assert.equal(merged.filter(({ id }) => id === 'same').length, 1);
  const capped = mergeChatMessage(
    Array.from({ length: 200 }, (_, index) => message(String(index), new Date(index * 1000).toISOString())),
    message('new', new Date(200 * 1000).toISOString())
  );
  assert.equal(capped.length, 200);
  assert.equal(capped[0].id, '1');
  assert.equal(capped.at(-1).id, 'new');
});

test('global button text follows its declared foreground color', async () => {
  const page = await readFile(new URL('../src/routes/+page.svelte', import.meta.url), 'utf8');
  assert.match(page, /:global\(button\)\{?-webkit-text-fill-color:currentColor/);
  assert.doesNotMatch(page, /:global\(button\)\{?-webkit-text-fill-color:#171717/);
});

test('private join requests show a disabled Requested state for the requester', async () => {
  const events = await readFile(new URL('../src/lib/data/events.js', import.meta.url), 'utf8');
  const page = await readFile(new URL('../src/routes/+page.svelte', import.meta.url), 'utf8');
  assert.ok(events.includes('hasRequested: pendingRequests.some('));
  assert.ok(events.includes('(request) => request.user_id === userId)'));
  assert.ok(page.includes("selectedEvent.visibility === 'Private' && selectedEvent.hasRequested"));
  assert.ok(page.includes('class="primary request-pending-button" disabled>Requested</button>'));
  assert.ok(page.includes('.primary.request-pending-button{background:#e6e6e6'));
});

test('validation toasts render above modal sheets and scrims', async () => {
  const page = await readFile(new URL('../src/routes/+page.svelte', import.meta.url), 'utf8');
  assert.ok(page.includes('.scrim{position:fixed;inset:0;background:rgba(0,0,0,.38);z-index:10000;'));
  assert.ok(page.includes('.toast{position:fixed;z-index:10002;'));
});


test('notices bounce in and dismiss after one second', async () => {
  const page = await readFile(new URL('../src/routes/+page.svelte', import.meta.url), 'utf8');
  assert.match(page, /function showNotice\(message\)[\s\S]*?\}, 1000\);/);
  assert.ok(page.includes('in:fly={{ y: 24, duration: 360, opacity: 0, easing: backOut }}'));
  assert.ok(page.includes('out:fly={{ y: 28, duration: 220, opacity: 0, easing: cubicIn }}'));
  assert.ok(page.includes('clearTimeout(noticeTimer)'));
});

test('event completion is blocked before start and confirmed independently of ratings', async () => {
  const page = await readFile(new URL('../src/routes/+page.svelte', import.meta.url), 'utf8');
  assert.ok(page.includes('eventStartTimestamp(selectedEvent) > Date.now()} onclick={finishSelectedEvent}'));
  assert.ok(page.includes('eventStartTimestamp(eventToFinish) > Date.now()'));
  assert.ok(page.includes("You can finish this event after its scheduled start time."));
  assert.ok(page.includes("if (result !== 'completed') throw new Error('The event was not marked as completed.')"));
  assert.ok(page.includes('await Promise.all([refreshEvents(), refreshStats()])'));
});


test('join-request result notice preserves the full event-full message', async () => {
  const page = await readFile(new URL('../src/routes/+page.svelte', import.meta.url), 'utf8');
  assert.ok(page.includes("showNotice(decision === 'full' ? 'Event is full; request was declined' : 'Request accepted');"));
  assert.ok(!page.includes("showNotice(decision === 'full' ? 'Event is full);"));
});

test('forward esports RPC requires skill, validates caller inputs, and keeps team size optional', async () => {
  const migration = await readFile(
    new URL('../supabase/migrations/20261107090000_fix_esports_creation_and_signup_metadata.sql', import.meta.url),
    'utf8'
  );
  assert.match(migration, /p_skill_level_code text,\s*p_team_size integer default null/i);
  assert.match(migration, /team_size, skill_level_code/i);
  assert.match(migration, /p_capacity is null or p_capacity < 2 or p_capacity > 1000/i);
  assert.match(migration, /where id = p_game_id and enabled/i);
  assert.match(migration, /where code = p_skill_level_code/i);
  assert.match(migration, /where id = auth\.uid\(\)/i);
  assert.match(migration, /security invoker/i);
});


test('shared layout applies border-box sizing to every route', async () => {
  const layout = await readFile(new URL('../src/routes/+layout.svelte', import.meta.url), 'utf8');
  assert.match(
    layout,
    /:global\(\*\),\s*:global\(\*::before\),\s*:global\(\*::after\)\s*\{\s*box-sizing:\s*border-box;/
  );
});


test('shared layout uses mobile-safe input sizing across all routes', async () => {
  const layout = await readFile(new URL('../src/routes/+layout.svelte', import.meta.url), 'utf8');
  assert.match(layout, /:global\(input\),\s*:global\(textarea\),\s*:global\(select\)\s*\{\s*font-size:\s*16px !important;/);
});


test('friend mutations serialize actions and disable all competing friend controls', async () => {
  const page = await readFile(new URL('../src/routes/+page.svelte', import.meta.url), 'utf8');
  assert.equal((page.match(/if \(friendAction\) return;/g) ?? []).length, 4);
  assert.doesNotMatch(page, /if \(friendAction === key\) return;/);
  for (const expression of [
    'disabled={Boolean(friendAction)} onclick={() => acceptFriendRequest(request)}',
    'disabled={Boolean(friendAction)} onclick={() => declineFriendRequest(request)}',
    'disabled={Boolean(friendAction)} onclick={() => sendFriendRequest(candidate)}',
    'disabled={Boolean(friendAction)} onclick={() => acceptSearchResult(candidate)}',
    'disabled={Boolean(friendAction)} onclick={() => removeFriend(friend)}'
  ]) {
    assert.ok(page.includes(expression), `Missing global friend-action lock on: ${expression}`);
  }
});


test('incoming friend request card keeps the profile, accept, and decline in separate columns', async () => {
  const page = await readFile(new URL('../src/routes/+page.svelte', import.meta.url), 'utf8');
  assert.match(
    page,
    /\.request-row\s*\{[^}]*grid-template-columns:\s*minmax\(0,\s*1fr\)\s+auto\s+auto;/
  );
  assert.match(page, /\.request-person\s*\{[^}]*min-width:\s*0;/);
  assert.match(page, /\.request-person \.friend-copy\s*\{[^}]*min-width:\s*0;/);
  assert.match(page, /\.request-action\s*\{[^}]*min-width:\s*60px;[^}]*white-space:\s*nowrap;/);
  assert.match(page, /@media\s*\(max-width:\s*360px\)\s*\{\s*\.request-row\s*\{[^}]*gap:\s*6px;/);
  assert.match(page, /class="request-action accept"/);
  assert.match(page, /class="request-action decline"/);
});


test('personal attendance stats ignore unreviewed memberships like public player stats', async () => {
  const { calculateAttendancePercent } = await import('../src/lib/data/stats-utils.js');
  assert.equal(calculateAttendancePercent([
    { showed_up: true },
    { showed_up: false },
    { showed_up: null }
  ]), 50);
  assert.equal(calculateAttendancePercent([
    { showed_up: true },
    { showed_up: true }
  ]), 100);
  assert.equal(calculateAttendancePercent([
    { showed_up: null },
    { showed_up: undefined }
  ]), null);
  assert.equal(calculateAttendancePercent([]), null);
});

test('notification and contact preferences save through one authenticated transaction', async () => {
  const profileData = await readFile(new URL('../src/lib/data/profile.js', import.meta.url), 'utf8');
  const page = await readFile(new URL('../src/routes/+page.svelte', import.meta.url), 'utf8');
  const migration = await readFile(
    new URL('../supabase/migrations/20261127100000_make_profile_settings_save_atomic.sql', import.meta.url),
    'utf8'
  );
  assert.match(profileData, /supabase\.rpc\('save_user_settings'/);
  assert.match(page, /const \{ error \} = await saveUserSettings\(/);
  assert.doesNotMatch(page, /await saveNotificationPreferences\(session\.id/);
  assert.doesNotMatch(page, /const contactError = await saveAccountProfile\(session\.id/);
  assert.match(migration, /security definer[\s\S]*set search_path = ''/i);
  assert.match(migration, /v_user_id uuid := auth\.uid\(\)/);
  assert.match(migration, /update public\.profiles[\s\S]*insert into public\.notification_preferences[\s\S]*on conflict \(user_id\)/i);
  assert.match(migration, /revoke all on function public\.save_user_settings\([\s\S]*from public, anon/i);
  assert.match(migration, /grant execute on function public\.save_user_settings\([\s\S]*to authenticated/i);
});
