<script>
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import AuthShell from '$lib/components/AuthShell.svelte';
  import {
    getSession,
    signIn,
    resetPassword
  } from '$lib/auth/session.js';

  let email = '';
  let password = '';
  let error = '';
  let loading = false;
  let showPassword = false;

  onMount(async () => {
    const session = await getSession();

    if (session) {
      goto('/');
    }
  });

  async function login() {
    error = '';

    const cleanEmail = email.trim();

    if (!cleanEmail) {
      error = 'Enter your email.';
      return;
    }

    if (!password) {
      error = 'Enter your password.';
      return;
    }

    loading = true;

    const { error: authError } = await signIn(cleanEmail, password);

    loading = false;

    if (authError) {
      error = authError.message;
      return;
    }

    goto('/');
  }

  async function handleForgotPassword() {
    error = '';

    const cleanEmail = email.trim();

    if (!cleanEmail) {
      error = 'Enter your email first.';
      return;
    }

    loading = true;

    const { error: resetError } = await resetPassword(cleanEmail);

    loading = false;

    if (resetError) {
      error = resetError.message;
      return;
    }

    alert('Password reset email sent. Check your inbox.');
  }
</script>

<svelte:head><title>Log in · Huddl</title></svelte:head>

<AuthShell eyebrow="WELCOME BACK" title="Good to see you." subtitle="Log in to find your next game and keep up with your people.">
  <form class="form" onsubmit={(event) => { event.preventDefault(); login(); }}>
    <label>Email
      <input
        type="email"
        bind:value={email}
        placeholder="you@example.com"
        autocomplete="email"
        disabled={loading}
      />
    </label>

    <label>Password
      <div class="password">
        <input
          type={showPassword ? 'text' : 'password'}
          bind:value={password}
          placeholder="Your password"
          autocomplete="current-password"
          disabled={loading}
        />
        <button
          type="button"
          onclick={() => showPassword = !showPassword}
          disabled={loading}
        >
          {showPassword ? 'Hide' : 'Show'}
        </button>
      </div>
    </label>

    {#if error}
      <p class="error">{error}</p>
    {/if}

    <button class="primary" type="submit" disabled={loading}>
      {loading ? 'Logging in…' : 'Log in'}
    </button>

    <button
      class="link-button"
      type="button"
      onclick={handleForgotPassword}
      disabled={loading}
    >
      Forgot password?
    </button>
  </form>

  <div class="divider"><span></span><small>NEW TO HUDDL?</small><span></span></div>

  <button class="secondary" type="button" onclick={() => goto('/signup')} disabled={loading}>
    Create an account
  </button>
</AuthShell>

<style>
  .form{display:grid;gap:14px;margin-top:22px}.form label{display:grid;gap:6px;font:800 11px Quicksand}.form input{height:47px;width:100%;border:2px solid #171717;border-radius:15px;background:#fff;padding:0 12px;outline:0;font:700 13px Quicksand}.form input:disabled{opacity:.65}.password{display:flex;gap:7px}.password input{min-width:0}.password button{border:2px solid #171717;border-radius:13px;background:#f3f3f3;padding:0 10px;font:800 10px Quicksand}.password button:disabled,.primary:disabled,.secondary:disabled,.link-button:disabled{opacity:.55;cursor:not-allowed}.primary,.secondary{width:100%;border:2px solid #171717;border-radius:17px;padding:14px;font:900 13px Quicksand}.primary{background:#171717;color:#fff;box-shadow:-4px 5px 0 #a1a2a4}.secondary{background:#fff}.link-button{border:0;background:transparent;color:#555;font:800 11px Quicksand;padding:1px}.error{margin:-3px 0 0;color:#a13d3d;font:800 11px Quicksand}.divider{display:grid;grid-template-columns:1fr auto 1fr;align-items:center;gap:9px;margin:20px 0 13px}.divider span{height:1px;background:#ddd}.divider small{color:#888;font:800 9px Quicksand;letter-spacing:.08em}
</style>
