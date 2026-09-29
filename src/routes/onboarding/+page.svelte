<script>
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import AuthShell from '$lib/components/AuthShell.svelte';
  import { getSession, getProfile, setProfile, clearSession } from '$lib/auth/session.js';

  const sports = ['Football', 'Volleyball', 'Tennis', 'Basketball', 'Badminton', 'Chess', 'Pool', 'Table Tennis', 'Cricket', 'Futsal', 'Squash', 'Box Cricket'];
  const levels = ['Beginner', 'Amateur', 'Intermediate', 'Seasoned', 'Professional'];
  /** @type {string[]} */
  let selected = [];
  /** @type {Record<string, string>} */
  let skills = {};
  /** @type {{ id: string, name: string, email: string } | null} */
  let user = null;
  let error = '';

  onMount(() => {
    user = getSession();
    if (!user) goto('/login');
    /** @type {{ sports?: string[], skills?: string[] } | null} */
    const existing = getProfile();
    if (existing?.sports) {
      selected = existing.sports;
      skills = Object.fromEntries(existing.sports.map((sport, index) => [sport, existing.skills?.[index] ?? 'Intermediate']));
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

  function finish() {
    if (!user) return;
    if (!selected.length) {
      error = 'Choose at least one sport.';
      return;
    }
    setProfile({
      name: user.name,
      handle: `@${user.name.toLowerCase().replace(/[^a-z0-9]+/g, '').slice(0, 18)}`,
      bio: 'Always down for a game.',
      sports: selected,
      skills: selected.map((sport) => skills[sport] ?? 'Intermediate')
    });
    goto('/');
  }

  function logout() {
    clearSession();
    goto('/login');
  }
</script>

<svelte:head><title>Set up Huddl</title></svelte:head>

<AuthShell eyebrow="ONE LAST STEP" title="What do you play?" subtitle="Pick your sports and tell us your current level. You can change this later.">
  <section class="setup">
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
    <button class="primary" type="button" onclick={finish}>Finish setup</button>
    <button class="skip" type="button" onclick={() => { selected = ['Football']; skills = { Football: 'Intermediate' }; finish(); }}>Use a default setup</button>
    <button class="logout" type="button" onclick={logout}>Not you? Sign out</button>
  </section>
</AuthShell>

<style>
  .setup{margin-top:21px}.sport-grid{display:grid;grid-template-columns:1fr 1fr;gap:9px}.sport-grid button{border:2px solid #171717;border-radius:17px;background:#fff;padding:13px 12px;display:flex;justify-content:space-between;align-items:center;text-align:left;font:900 12px Quicksand;box-shadow:-3px 4px 0 #ddd}.sport-grid button.selected{background:#e9e5ff;box-shadow:-3px 4px 0 #a1a2a4}.sport-grid span{font-size:14px}.levels{margin-top:22px}.section-head{display:flex;justify-content:space-between;align-items:baseline;margin-bottom:9px}.section-head h2{margin:0;font:900 17px Nunito}.section-head span{color:#777;font:700 10px Quicksand}.level-row{padding:11px 0;border-top:1px solid #ddd}.level-row>strong{display:block;font:900 12px Quicksand;margin-bottom:8px}.level-row>div{display:grid;grid-template-columns:repeat(3,1fr);gap:6px}.level-row button{border:1.5px solid #171717;border-radius:11px;background:#fff;padding:8px 4px;font:800 9px Quicksand}.level-row button.active{background:#dcecff}.primary,.skip,.logout{width:100%;border:2px solid #171717;border-radius:17px;padding:13px;font:900 12px Quicksand;margin-top:15px}.primary{background:#171717;color:#fff;box-shadow:-4px 5px 0 #a1a2a4}.skip{background:#fff;margin-top:10px}.logout{border:0;background:transparent;color:#888;padding:8px;margin-top:8px}.error{color:#a13d3d;font:800 11px Quicksand;margin:13px 0 0}
</style>
