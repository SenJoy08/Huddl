<script>
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase/client.js';

  let error = '';
  let loading = true;

  onMount(async () => {
    try {
      const params = new URLSearchParams(window.location.search);
      const code = params.get('code');
      const next = params.get('next') || '/onboarding';

      if (!code) {
        error = 'Missing authentication code. Request a new confirmation email and try again.';
        loading = false;
        return;
      }

      const { error: exchangeError } = await supabase.auth.exchangeCodeForSession(code);
      if (exchangeError) {
        error = exchangeError.message || 'This confirmation link is invalid or has expired.';
        loading = false;
        return;
      }

      const safeNext = next.startsWith('/') && !next.startsWith('//') ? next : '/onboarding';
      const { data: authData, error: userError } = await supabase.auth.getUser();
      if (userError) throw userError;

      if (authData.user) {
        const { data: savedSports, error: sportsError } = await supabase
          .from('profile_sports')
          .select('sport_id')
          .eq('profile_id', authData.user.id)
          .limit(1);

        // A read failure should fall back to the app's normal profile gate.
        // The gate sends incomplete accounts to onboarding.
        if (sportsError || savedSports?.length) {
          goto('/');
          return;
        }
      }

      goto(safeNext);
    } catch (callbackError) {
      console.error('Authentication callback failed:', callbackError);
      error = 'Could not complete confirmation. Check your connection and try the link again.';
      loading = false;
    }
  });
</script>

<svelte:head>
  <title>Confirming account · Huddl</title>
</svelte:head>

<div class="page">
  {#if loading}
    <div class="card">
      <strong>Confirming your account…</strong>
      <span>Please wait.</span>
    </div>
  {:else}
    <div class="card">
      <strong>Could not complete confirmation</strong>
      <span>{error}</span>
      <a href="/login">Back to login</a>
    </div>
  {/if}
</div>

<style>
  .page {
    min-height: 100vh;
    display: grid;
    place-items: center;
    padding: 24px;
    background: #fbfbfb;
    color: #171717;
    font-family: Nunito, Arial, sans-serif;
  }

  .card {
    width: min(100%, 360px);
    display: grid;
    gap: 8px;
    padding: 24px;
    border: 2px solid #171717;
    border-radius: 22px;
    background: #fff;
    box-shadow: -5px 6px 0 #a1a2a4;
  }

  .card strong {
    font: 900 18px Nunito, Arial, sans-serif;
  }

  .card span {
    color: #777;
    font: 700 12px Quicksand, sans-serif;
  }

  .card a {
    margin-top: 8px;
    color: #171717;
    font: 900 12px Quicksand, sans-serif;
  }
</style>
