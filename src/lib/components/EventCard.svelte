<script>
  import Icon from './Icon.svelte';
  export let event;
  export let onOpen = () => {};
  export let onHostClick = () => {};
  $: progress = Math.round((event.members / event.capacity) * 100);
</script>

<article class="card {event.color}">
  <button class="card-main" type="button" onclick={onOpen} aria-label={`Open ${event.title}`}>
    <div class="topline"><span>{event.sport}</span><span>{event.status === 'full' ? 'FULL' : event.skill}</span></div>
    <h3>{event.title}</h3>
    <div class="meta"><span><Icon name="calendar" size={15} />{event.date}</span><span><Icon name="map" size={15} />{event.location}</span></div>
    <div class="progress-wrap">
      <div class="progress"><span style={`width:${progress}%`}></span></div>
      <strong>{event.members}/{event.capacity}</strong>
    </div>
  </button>
  <div class="footer">
    <span>Hosted by <button type="button" class="host-link" onclick={(clickEvent) => { clickEvent.stopPropagation(); onHostClick(); }}>{event.host}</button></span>
    <span class="arrow"><Icon name="chevron" size={17} /></span>
  </div>
</article>

<style>
  .card{width:100%;text-align:left;border:2px solid #171717;border-radius:24px;padding:17px;background:#fff;box-shadow:-6px 7px 0 #a1a2a4;display:block;color:#171717;transition:transform .15s;overflow:hidden}.card:active{transform:translate(-2px,2px);box-shadow:-4px 5px 0 #a1a2a4}.card.blue{background:#eef6ff}.card.peach{background:#fff0e7}.card.lavender{background:#f2efff}.card.mint{background:#e9f8f0}
  .card-main{width:100%;border:0;background:transparent;padding:0;text-align:left;color:inherit;display:block}.card-main:active{transform:translate(-2px,2px)}
  .topline,.footer,.meta,.meta span{display:flex;align-items:center}.topline{justify-content:space-between;font:700 11px Quicksand,sans-serif;text-transform:uppercase;letter-spacing:.02em}.topline span:first-child{background:#fff;border:1.5px solid #171717;border-radius:999px;padding:5px 9px}.topline span:last-child{color:#6f6f6f}
  h3{font:900 22px/1.05 Nunito,sans-serif;margin:14px 0 13px;letter-spacing:-.02em}.meta{gap:14px;color:#5f5f5f;flex-wrap:wrap}.meta span{gap:5px;font:700 12px Quicksand,sans-serif;word-spacing:.02em;letter-spacing:.005em}.progress-wrap{display:flex;align-items:center;gap:9px;margin-top:16px}.progress{height:8px;background:#fff;border:1.5px solid #171717;border-radius:999px;overflow:hidden;flex:1}.progress span{display:block;height:100%;background:#7e9fe7;border-radius:999px}.progress-wrap strong{font:900 11px Quicksand,sans-serif}.footer{justify-content:space-between;margin-top:13px;padding-top:11px;border-top:1.5px solid rgba(23,23,23,.14);font:700 11px Quicksand,sans-serif;color:#656565;letter-spacing:.005em;word-spacing:.02em}.host-link{border:0;background:transparent;padding:0;color:inherit;font:inherit;text-decoration:underline;text-decoration-thickness:1px;text-underline-offset:2px}.host-link:active{opacity:.6}.arrow{display:grid;place-items:center;width:28px;height:28px;border:1.5px solid #171717;border-radius:50%;background:#fff;color:#171717}
</style>
