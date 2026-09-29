<script>
  export let eyebrow = 'WELCOME TO HUDDL';
  export let title = 'Find your next game.';
  export let subtitle = '';
</script>

<div class="auth-page">
  <div class="auth-orb orb-one"></div>
  <div class="auth-orb orb-two"></div>
  <main class="auth-wrap">
    <header class="brand">
      <div class="brand-mark">H</div>
      <div><strong>HUDDL</strong><span>Play together.</span></div>
    </header>
    <section class="auth-card">
      <p class="eyebrow">{eyebrow}</p>
      <h1>{title}</h1>
      {#if subtitle}<p class="subtitle">{subtitle}</p>{/if}
      <slot />
    </section>
    <p class="footer-note">Built for finding people who want to play.</p>
  </main>
</div>

<style>
  .auth-page{min-height:100vh;background:#fbfbfb;color:#171717;position:relative;overflow:hidden;font-family:Nunito,Arial,sans-serif;display:flex;justify-content:center}
  .auth-wrap{width:min(100%,430px);min-height:100vh;padding:28px 16px 30px;display:flex;flex-direction:column;position:relative;z-index:1}
  .brand{display:flex;align-items:center;gap:11px;margin-bottom:34px}
  .brand-mark{width:43px;height:43px;border:2px solid #171717;border-radius:15px;background:#dcecff;display:grid;place-items:center;font:900 21px Nunito;box-shadow:-4px 5px 0 #a1a2a4}
  .brand strong{display:block;font:900 15px Quicksand;letter-spacing:.08em}.brand span{display:block;color:#777;font:700 10px Quicksand;margin-top:1px}
  .auth-card{background:#fff;border:2px solid #171717;border-radius:27px;padding:23px 19px 20px;box-shadow:-6px 8px 0 #a1a2a4}
  .eyebrow{margin:0 0 7px;font:800 11px Quicksand;letter-spacing:.09em;color:#777}.auth-card h1{margin:0;font:900 31px/1.02 Nunito;letter-spacing:-.03em}.subtitle{margin:9px 0 0;color:#777;font:700 12px/1.45 Quicksand}
  .footer-note{margin:24px auto 0;color:#888;text-align:center;font:700 10px Quicksand}
  .auth-orb{position:absolute;border:2px solid #171717;border-radius:50%;opacity:.6}.orb-one{width:150px;height:150px;background:#ffe5d4;right:-95px;top:105px}.orb-two{width:105px;height:105px;background:#e9e5ff;left:-62px;bottom:90px}
</style>
