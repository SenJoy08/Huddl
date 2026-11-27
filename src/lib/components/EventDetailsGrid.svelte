<script>
  import Icon from './Icon.svelte';
  export let event;
  $: canSeeLocation = event.visibility !== 'Private' || event.isMember;
</script>

<div class="detail-grid">
  <div><Icon name="calendar" size={19}/><span>{event.date}</span></div>
  {#if canSeeLocation}<div><Icon name="map" size={19}/><span>{event.location}</span></div>{/if}
  {#if event.eventType === 'esports'}
    {#if event.platform}<div><Icon name="monitor" size={19}/><span>{event.platform}</span></div>{/if}
    {#if event.gameMode}<div><Icon name="gamepad" size={19}/><span>{event.gameMode}</span></div>{/if}
  {/if}
</div>

<style>
  .detail-grid{display:grid;grid-template-columns:1fr 1fr;gap:9px;margin:17px 0 16px}
  .detail-grid div{display:grid;grid-template-columns:22px minmax(0,1fr);align-items:center;gap:8px;min-width:0;background:#fff;border:2px solid #171717;border-radius:17px;padding:12px;font:800 11px/1.2 Quicksand;box-shadow:-2px 3px 0 #e3e3e3}
  .detail-grid div span{min-width:0;overflow-wrap:anywhere}
  @media(max-width:360px){.detail-grid{grid-template-columns:1fr}}
</style>
