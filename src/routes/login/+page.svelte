<script>
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import AuthShell from '$lib/components/AuthShell.svelte';
  import { getSession, setSession } from '$lib/auth/session.js';

  let email = '';
  let password = '';
  let error = '';
  let showPassword = false;

  onMount(() => {
    if (getSession()) goto('/');
  });

  function login() {
    error = '';
    if (!email.trim() || !password) {
      error = 'Enter your email and password.';
      return;
    }
    if (!email.includes('@')) {
      error = 'Enter a valid email address.';
      return;
    }
    const name = email.split('@')[0].replace(/[._-]+/g, ' ').replace(/\b\w/g, (char) => char.toUpperCase());
    setSession({ id: 'user-1', name, email: email.trim() });
    goto('/');
  }
</script>

<svelte:head><title>Log in · Huddl</title></svelte:head>

<AuthShell eyebrow="WELCOME BACK" title="Good to see you." subtitle="Log in to find your next game and keep up with your people.">
  <form class="form" onsubmit={(event) => { event.preventDefault(); login(); }}>
    <label>Email<input type="email" bind:value={email} placeholder="you@example.com" autocomplete="email" /></label>
    <label>Password
      <div class="password"><input type={showPassword ? 'text' : 'password'} bind:value={password} placeholder="Your password" autocomplete="current-password" /><button type="button" onclick={() => showPassword = !showPassword}>{showPassword ? 'Hide' : 'Show'}</button></div>
    </label>
    {#if error}<p class="error">{error}</p>{/if}
    <button class="primary" type="submit">Log in</button>
    <button class="link-button" type="button" onclick={() => alert('Password reset will be connected to Supabase Auth later.')}>Forgot password?</button>
  </form>
  <div class="divider"><span></span><small>NEW TO HUDDL?</small><span></span></div>
  <button class="secondary" type="button" onclick={() => goto('/signup')}>Create an account</button>
</AuthShell>

<style>
  .form{display:grid;gap:14px;margin-top:22px}.form label{display:grid;gap:6px;font:800 11px Quicksand}.form input{height:47px;width:100%;border:2px solid #171717;border-radius:15px;background:#fff;padding:0 12px;outline:0;font:700 13px Quicksand}.password{display:flex;gap:7px}.password input{min-width:0}.password button{border:2px solid #171717;border-radius:13px;background:#f3f3f3;padding:0 10px;font:800 10px Quicksand}.primary,.secondary{width:100%;border:2px solid #171717;border-radius:17px;padding:14px;font:900 13px Quicksand}.primary{background:#171717;color:#fff;box-shadow:-4px 5px 0 #a1a2a4}.secondary{background:#fff}.link-button{border:0;background:transparent;color:#555;font:800 11px Quicksand;padding:1px}.error{margin:-3px 0 0;color:#a13d3d;font:800 11px Quicksand}.divider{display:grid;grid-template-columns:1fr auto 1fr;align-items:center;gap:9px;margin:20px 0 13px}.divider span{height:1px;background:#ddd}.divider small{color:#888;font:800 9px Quicksand;letter-spacing:.08em}
</style>
