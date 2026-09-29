<script>
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import AuthShell from '$lib/components/AuthShell.svelte';
  import { getSession, setSession } from '$lib/auth/session.js';

  let name = '';
  let email = '';
  let password = '';
  let confirmPassword = '';
  let error = '';

  onMount(() => {
    if (getSession()) goto('/');
  });

  function signup() {
    error = '';
    if (!name.trim() || !email.trim() || !password || !confirmPassword) {
      error = 'Fill in every field.';
      return;
    }
    if (!email.includes('@')) {
      error = 'Enter a valid email address.';
      return;
    }
    if (password.length < 6) {
      error = 'Password must be at least 6 characters.';
      return;
    }
    if (password !== confirmPassword) {
      error = 'Passwords do not match.';
      return;
    }
    setSession({ id: 'user-1', name: name.trim(), email: email.trim() });
    goto('/onboarding');
  }
</script>

<svelte:head><title>Create account · Huddl</title></svelte:head>

<AuthShell eyebrow="CREATE YOUR HUDDL" title="Start playing." subtitle="Set up your account first. We'll personalize your games next.">
  <form class="form" onsubmit={(event) => { event.preventDefault(); signup(); }}>
    <label>Your name<input bind:value={name} placeholder="Sanjay Shashibushan" autocomplete="name" /></label>
    <label>Email<input type="email" bind:value={email} placeholder="you@example.com" autocomplete="email" /></label>
    <label>Password<input type="password" bind:value={password} placeholder="At least 6 characters" autocomplete="new-password" /></label>
    <label>Confirm password<input type="password" bind:value={confirmPassword} placeholder="Enter it again" autocomplete="new-password" /></label>
    {#if error}<p class="error">{error}</p>{/if}
    <button class="primary" type="submit">Create account</button>
  </form>
  <div class="divider"><span></span><small>ALREADY A MEMBER?</small><span></span></div>
  <button class="secondary" type="button" onclick={() => goto('/login')}>Log in</button>
</AuthShell>

<style>
  .form{display:grid;gap:12px;margin-top:22px}.form label{display:grid;gap:6px;font:800 11px Quicksand}.form input{height:46px;width:100%;border:2px solid #171717;border-radius:15px;background:#fff;padding:0 12px;outline:0;font:700 13px Quicksand}.primary,.secondary{width:100%;border:2px solid #171717;border-radius:17px;padding:14px;font:900 13px Quicksand}.primary{background:#171717;color:#fff;box-shadow:-4px 5px 0 #a1a2a4}.secondary{background:#fff}.error{margin:-2px 0 0;color:#a13d3d;font:800 11px Quicksand}.divider{display:grid;grid-template-columns:1fr auto 1fr;align-items:center;gap:9px;margin:20px 0 13px}.divider span{height:1px;background:#ddd}.divider small{color:#888;font:800 9px Quicksand;letter-spacing:.08em}
</style>
