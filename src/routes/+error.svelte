<script>
  import { goto } from '$app/navigation';
</script>

<svelte:head>
  <title>Huddl · Something went wrong</title>
  <meta name="description" content="Huddl could not open this page." />
</svelte:head>

<main class="error-page">
  <div class="error-card">
    <p class="eyebrow">HUDDL</p>
    <h1>Something went wrong.</h1>
    <p>That page could not be loaded. Return to Huddl and try again.</p>
    <div class="actions">
      <button class="primary" type="button" onclick={() => goto('/')}>Back to Huddl</button>
      <button class="secondary" type="button" onclick={() => history.back()}>Go back</button>
    </div>
  </div>
</main>

<style>
  .error-page{min-height:100vh;display:grid;place-items:center;padding:24px;background:#fbfbfb;font-family:Nunito,sans-serif;color:#171717}
  .error-card{width:min(100%,390px);border:2px solid #171717;border-radius:28px;background:#fff;padding:24px;box-shadow:-6px 7px 0 #a1a2a4}
  .eyebrow{margin:0 0 7px;color:#777;font:900 10px Quicksand,sans-serif;letter-spacing:.1em}
  h1{margin:0;font:900 30px/1.05 Nunito,sans-serif;letter-spacing:-.03em}
  p:not(.eyebrow){margin:12px 0 0;color:#666;font:700 12px/1.5 Quicksand,sans-serif}
  .actions{display:grid;gap:10px;margin-top:22px}
  button{width:100%;border:2px solid #171717;border-radius:17px;padding:14px;font:900 13px Quicksand,sans-serif}
  .primary{background:#171717;color:#fff;box-shadow:-4px 5px 0 #a1a2a4}
  .secondary{background:#fff}
  button:active{transform:translate(-1px,1px)}
</style>
