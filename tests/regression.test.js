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
