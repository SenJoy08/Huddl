<script>
  import { goto } from '$app/navigation';
  import { onDestroy, onMount } from 'svelte';
  import AuthShell from '$lib/components/AuthShell.svelte';
  import { getSession, onAuthStateChange, updatePassword } from '$lib/auth/session.js';

  let password = '';
  let confirmPassword = '';
  let error = '';
  let loading = false;
  let checkingSession = true;
  let canReset = false;
  let showPassword = false;
  let showConfirmPassword = false;
  let success = false;
  /** @type {{ data: { subscription: { unsubscribe: () => void } } } | null} */
  let subscription = null;

  onMount(async () => {
    subscription = onAuthStateChange((event, session) => {
      if (event === 'PASSWORD_RECOVERY' && session) {
        canReset = true;
        checkingSession = false;
      } else if (session && checkingSession) {
        canReset = true;
        checkingSession = false;
      }
    });

    const session = await getSession();
    if (session) {
      canReset = true;
    } else {
      error = 'This password reset link is invalid or has expired.';
    }
    checkingSession = false;
  });

  onDestroy(() => {
    subscription?.data?.subscription?.unsubscribe?.();
  });

  async function savePassword() {
    error = '';

    if (!canReset) {
      error = 'This password reset link is invalid or has expired.';
      return;
    }

    if (password.length < 6) {
      error = 'Your new password must be at least 6 characters.';
      return;
    }

    if (password !== confirmPassword) {
      error = 'The passwords do not match.';
      return;
    }

    loading = true;
    const { error: passwordError } = await updatePassword(password);
    loading = false;

    if (passwordError) {
      error = passwordError.message || 'Could not update your password.';
      return;
    }

    success = true;
    password = '';
    confirmPassword = '';
  }
</script>

<svelte:head><title>Reset password · Huddl</title></svelte:head>

{#if checkingSession}
  <div class="auth-loading">Checking your reset link…</div>
{:else if success}
  <AuthShell eyebrow="PASSWORD UPDATED" title="You're all set." subtitle="Your password has been changed successfully.">
    <button class="primary" type="button" onclick={() => goto('/')}>
      Continue to Huddl
    </button>
  </AuthShell>
{:else if canReset}
  <AuthShell eyebrow="RESET PASSWORD" title="Choose a new password." subtitle="Use a new password you will remember. It must be at least 6 characters.">
    <form class="form" onsubmit={(event) => { event.preventDefault(); savePassword(); }}>
      <label>New password
        <div class="password">
          <input
            type={showPassword ? 'text' : 'password'}
            bind:value={password}
            placeholder="New password"
            autocomplete="new-password"
            disabled={loading}
          />
          <button type="button" onclick={() => showPassword = !showPassword} disabled={loading}>
            {showPassword ? 'Hide' : 'Show'}
          </button>
        </div>
      </label>

      <label>Confirm password
        <div class="password">
          <input
            type={showConfirmPassword ? 'text' : 'password'}
            bind:value={confirmPassword}
            placeholder="Repeat your password"
            autocomplete="new-password"
            disabled={loading}
          />
          <button type="button" onclick={() => showConfirmPassword = !showConfirmPassword} disabled={loading}>
            {showConfirmPassword ? 'Hide' : 'Show'}
          </button>
        </div>
      </label>

      {#if error}
        <p class="error" role="alert">{error}</p>
      {/if}

      <button class="primary" type="submit" disabled={loading}>
        {loading ? 'Updating password…' : 'Update password'}
      </button>

      <button class="link-button" type="button" onclick={() => goto('/login')} disabled={loading}>
        Back to log in
      </button>
    </form>
  </AuthShell>
{:else}
  <AuthShell eyebrow="RESET LINK" title="This link has expired." subtitle="Request a new password reset email and try again.">
    <button class="primary" type="button" onclick={() => goto('/login')}>
      Back to log in
    </button>
  </AuthShell>
{/if}

<style>
  .auth-loading{min-height:100vh;background:#fbfbfb;display:grid;place-items:center;color:#777;font:800 12px Quicksand,sans-serif}
  .form{display:grid;gap:14px;margin-top:22px}.form label{display:grid;gap:6px;font:800 11px Quicksand}.form input{height:47px;width:100%;border:2px solid #171717;border-radius:15px;background:#fff;padding:0 12px;outline:0;font:700 13px Quicksand}.form input:disabled{opacity:.65}.password{display:flex;gap:7px}.password input{min-width:0}.password button{border:2px solid #171717;border-radius:13px;background:#f3f3f3;padding:0 10px;font:800 10px Quicksand}.password button:disabled,.primary:disabled,.link-button:disabled{opacity:.55;cursor:not-allowed}.primary{width:100%;border:2px solid #171717;border-radius:17px;padding:14px;font:900 13px Quicksand;background:#171717;color:#fff;box-shadow:-4px 5px 0 #a1a2a4}.link-button{border:0;background:transparent;color:#555;font:800 11px Quicksand;padding:1px}.error{margin:-3px 0 0;color:#a13d3d;font:800 11px Quicksand}
</style>
