<script>
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import AuthShell from '$lib/components/AuthShell.svelte';
  import { getSession, signOut } from '$lib/auth/session.js';
  import { supabase } from '$lib/supabase/client.js';

  const sports = ['Football', 'Volleyball', 'Tennis', 'Basketball', 'Badminton', 'Chess', 'Pool', 'Table Tennis', 'Cricket', 'Futsal', 'Squash', 'Box Cricket'];
  const levels = ['Beginner', 'Amateur', 'Intermediate', 'Seasoned', 'Professional'];
  /** @type {string[]} */
  let selected = [];
  /** @type {Record<string, string>} */
  let skills = {};
  /** @type {{ id: string, name: string, email: string } | null} */
  let user = null;
  let error = '';
  let saving = false;

  /** @param {unknown} issue @param {string} fallback */
  function userFacingError(issue, fallback) {
    const message = issue instanceof Error ? issue.message : String(issue ?? '');
    const normalized = message.toLowerCase();
    if (normalized.includes('failed to fetch') || normalized.includes('network')) return 'Check your internet connection and try again.';
    if (normalized.includes('not authenticated') || normalized.includes('jwt') || normalized.includes('session')) return 'Your session has expired. Please log in again.';
    if (normalized.includes('duplicate') || normalized.includes('already exists') || normalized.includes('unique constraint')) return 'Your setup conflicts with an existing value. Try again.';
    return fallback;
  }

  onMount(async () => {
    const authSession = await getSession();

    if (!authSession) {
      goto('/login');
      return;
    }

    user = {
      id: authSession.user.id,
      name:
        authSession.user.user_metadata?.name ??
        authSession.user.email?.split('@')[0] ??
        'Player',
      email: authSession.user.email ?? ''
    };

    const [{ data: existingProfile }, { data: existingSports }] = await Promise.all([
      supabase
        .from('profiles')
        .select('display_name, handle, bio')
        .eq('id', user.id)
        .maybeSingle(),
      supabase
        .from('profile_sports')
        .select('sport_id, skill_level_code, sports(name), skill_levels(name)')
        .eq('profile_id', user.id)
    ]);

    if (existingProfile?.display_name) {
      user = { ...user, name: existingProfile.display_name };
    }

    if (existingSports?.length) {
      selected = existingSports
        .map((row) => row.sports?.[0]?.name)
        .filter(Boolean);

      skills = Object.fromEntries(
        existingSports
          .filter((row) => row.sports?.[0]?.name)
          .map((row) => [
            row.sports[0].name,
            row.skill_levels?.[0]?.name ?? 'Intermediate'
          ])
      );
    }
  });

  /** @param {string} sport */
  function toggleSport(sport) {
    if (selected.includes(sport)) {
      selected = selected.filter((item) => item !== sport);
      const next = { ...skills };
      delete next[sport];
      skills = next;
      return;
    }
    selected = [...selected, sport];
    skills = { ...skills, [sport]: 'Intermediate' };
  }

  async function finish() {
    if (!user || saving) return;

    const userId = user.id;

    if (!selected.length) {
      error = 'Choose at least one sport.';
      return;
    }

    error = '';
    saving = true;

    try {
      const handleBase = user.name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '')
      .slice(0, 18) || `player${user.id.slice(0, 6)}`;

    const { data: existingProfile, error: existingProfileError } = await supabase
      .from('profiles')
      .select('handle')
      .eq('id', user.id)
      .maybeSingle();

    if (existingProfileError) {
      error = userFacingError(existingProfileError, 'Could not load your profile. Please try again.');
      saving = false;
      return;
    }

    let finalHandle = existingProfile?.handle ?? `@${handleBase}`;

    if (existingProfile) {
      const { error: profileError } = await supabase
        .from('profiles')
        .update({
          display_name: user.name,
          handle: finalHandle,
          bio: 'Always down for a game.'
        })
        .eq('id', user.id);

      if (profileError) {
        error = userFacingError(profileError, 'Could not save your profile. Please try again.');
        saving = false;
      return;
      }
    } else {
      const { data: handleConflict, error: handleLookupError } = await supabase
        .from('profiles')
        .select('id')
        .eq('handle', finalHandle)
        .maybeSingle();

      if (handleLookupError) {
        error = userFacingError(handleLookupError, 'Could not check your handle. Please try again.');
        saving = false;
      return;
      }

      if (handleConflict) {
        const suffix = user.id.slice(0, 6).toLowerCase();
        const baseLength = Math.max(1, 18 - suffix.length - 1);
        finalHandle = `@${handleBase.slice(0, baseLength)}_${suffix}`;
      }

      const { error: profileError } = await supabase
        .from('profiles')
        .insert({
          id: user.id,
          display_name: user.name,
          handle: finalHandle,
          bio: 'Always down for a game.'
        });

      if (profileError) {
        error = userFacingError(profileError, 'Could not save your profile. Please try again.');
        saving = false;
      return;
      }
    }

    const { data: sportRows, error: sportsError } = await supabase
      .from('sports')
      .select('id, name')
      .in('name', selected);

    if (sportsError) {
      error = userFacingError(sportsError, 'Could not load the sports list. Please try again.');
      saving = false;
      return;
    }

    const { data: skillRows, error: skillsError } = await supabase
      .from('skill_levels')
      .select('code, name')
      .in('name', levels);

    if (skillsError) {
      error = userFacingError(skillsError, 'Could not load skill levels. Please try again.');
      saving = false;
      return;
    }

    const sportIdByName = new Map(
      (sportRows ?? []).map((row) => [row.name, row.id])
    );
    const skillCodeByName = new Map(
      (skillRows ?? []).map((row) => [row.name, row.code])
    );

    const profileSports = selected.map((sport) => ({
      profile_id: userId,
      sport_id: sportIdByName.get(sport),
      skill_level_code: skillCodeByName.get(skills[sport] ?? 'Intermediate')
    }));

    if (profileSports.some((row) => !row.sport_id || !row.skill_level_code)) {
      error = 'Could not match one or more sports or skill levels.';
      saving = false;
      return;
    }

    const { error: deleteSportsError } = await supabase
      .from('profile_sports')
      .delete()
      .eq('profile_id', user.id);

    if (deleteSportsError) {
      error = userFacingError(deleteSportsError, 'Could not update your sports. Please try again.');
      saving = false;
      return;
    }

    const { error: insertSportsError } = await supabase
      .from('profile_sports')
      .insert(profileSports);

    if (insertSportsError) {
      error = userFacingError(insertSportsError, 'Could not save your sports. Please try again.');
      saving = false;
      return;
    }

    const { data: existingPreferences, error: preferencesLookupError } = await supabase
      .from('notification_preferences')
      .select('user_id')
      .eq('user_id', user.id)
      .maybeSingle();

    if (preferencesLookupError) {
      error = userFacingError(preferencesLookupError, 'Could not load your preferences. Please try again.');
      saving = false;
      return;
    }

    const preferencePayload = {
      user_id: user.id,
      event_updates: true,
      friend_updates: true,
      rating_reminders: true
    };

    const { error: preferencesError } = existingPreferences
      ? await supabase.from('notification_preferences').update(preferencePayload).eq('user_id', user.id)
      : await supabase.from('notification_preferences').insert(preferencePayload);

    if (preferencesError) {
      error = userFacingError(preferencesError, 'Could not save your preferences. Please try again.');
      saving = false;
      return;
    }

      goto('/');
    } catch (setupError) {
      console.error('Onboarding save failed:', setupError);
      error = userFacingError(setupError, 'Could not finish setup right now. Please try again.');
    } finally {
      saving = false;
    }
  }

  async function logout() {
    const { error: signOutError } = await signOut();
    if (signOutError) {
      error = userFacingError(signOutError, 'Could not sign out right now. Please try again.');
      return;
    }
    goto('/login');
  }
</script>

<svelte:head><title>Set up Huddl</title></svelte:head>

<AuthShell eyebrow="ONE LAST STEP" title="What do you play?" subtitle="Pick your sports and tell us your current level. You can change this later.">
  <section class="setup" aria-busy={saving}>
    <div class="sport-grid selection-grid">
      {#each sports as sport}
        <button class:selected={selected.includes(sport)} type="button" onclick={() => toggleSport(sport)}>{sport}<span>{selected.includes(sport) ? '✓' : '+'}</span></button>
      {/each}
    </div>

    {#if selected.length}
      <div class="levels selection-section">
        <div class="section-head"><h2>Your levels</h2><span>{selected.length} selected</span></div>
        {#each selected as sport}
          <div class="level-row">
            <strong>{sport}</strong>
            <div>{#each levels as level}<button class:active={skills[sport] === level} type="button" onclick={() => skills = { ...skills, [sport]: level }}>{level}</button>{/each}</div>
          </div>
        {/each}
      </div>
    {/if}

    {#if error}<p class="error">{error}</p>{/if}
    <button class="primary" type="button" disabled={saving} onclick={finish}>{saving ? 'Saving setup…' : 'Finish setup'}</button>
    <button class="skip" type="button" disabled={saving} onclick={() => { selected = ['Football']; skills = { Football: 'Intermediate' }; finish(); }}>Use a default setup</button>
    <button class="logout" type="button" disabled={saving} onclick={logout}>Not you? Sign out</button>
  </section>
</AuthShell>

<style>
  .setup{margin-top:21px}.sport-grid{display:grid;grid-template-columns:1fr 1fr;gap:9px}.sport-grid button{border:2px solid #171717;border-radius:17px;background:#fff;padding:13px 12px;display:flex;justify-content:space-between;align-items:center;text-align:left;font:900 12px Quicksand;box-shadow:-3px 4px 0 #ddd}.sport-grid button.selected{background:#e9e5ff;box-shadow:-3px 4px 0 #a1a2a4}.sport-grid span{font-size:14px}.levels{margin-top:22px}.section-head{display:flex;justify-content:space-between;align-items:baseline;margin-bottom:9px}.section-head h2{margin:0;font:900 17px Nunito}.section-head span{color:#777;font:700 10px Quicksand}.level-row{padding:11px 0;border-top:1px solid #ddd}.level-row>strong{display:block;font:900 12px Quicksand;margin-bottom:8px}.level-row>div{display:grid;grid-template-columns:repeat(3,1fr);gap:6px}.level-row button{border:1.5px solid #171717;border-radius:11px;background:#fff;padding:8px 4px;font:800 9px Quicksand}.level-row button.active{background:#dcecff}.primary,.skip,.logout{width:100%;border:2px solid #171717;border-radius:17px;padding:13px;font:900 12px Quicksand;margin-top:15px}.primary:disabled,.skip:disabled,.logout:disabled{opacity:.55;cursor:not-allowed}.primary{background:#171717;color:#fff;box-shadow:-4px 5px 0 #a1a2a4}.skip{background:#fff;margin-top:10px}.logout{border:0;background:transparent;color:#888;padding:8px;margin-top:8px}.error{color:#a13d3d;font:800 11px Quicksand;margin:13px 0 0}
</style>
