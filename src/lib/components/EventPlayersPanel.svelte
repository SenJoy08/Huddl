<script>
  export let event;

  /** @type {(id: string) => string} */
  export let avatarColorForId = (id) => 'blue';

  /** @type {(playerId: string, player?: any) => void | Promise<void>} */
  export let onOpenPlayer = (_playerId, _player) => {};
  $: progress = Math.round(((event.members ?? 0) / Math.max(event.capacity ?? 1, 1)) * 100);
</script>

<section class="panel players-panel">
  <div class="panel-head"><div><h2>Players</h2><span class="panel-subtitle">Who's in the game</span></div><strong>{event.members ?? 0}/{event.capacity ?? 0}</strong></div>
  <div class="big-progress"><span style={`width:${progress}%`}></span></div>
  <div class="player-count-line"><span>{Math.max((event.capacity ?? 0) - (event.members ?? 0), 0)} spots left</span><span>{progress}% filled</span></div>
  <div class="avatars">
    {#each event.memberProfiles ?? [] as player (player.id)}
      <button type="button" class="profile-avatar-chip {avatarColorForId(player.id)}" aria-label={`Open ${player.name}'s profile`} onclick={() => onOpenPlayer(player.id, player)}>{player.name[0]?.toUpperCase() ?? '?'}</button>
    {/each}
    {#if (event.memberProfiles?.length ?? 0) < (event.members ?? 0)}<span class="empty">+</span>{/if}
  </div>
</section>

<style>
  .panel{background:#fff;border:2px solid #171717;border-radius:22px;padding:17px;box-shadow:-5px 6px 0 #a1a2a4;margin-bottom:18px}
  .panel-head{display:flex;align-items:center;justify-content:space-between;margin-bottom:16px}
  .panel-head>div{display:grid;gap:3px}
  .panel h2{margin:0;font:900 21px Nunito,sans-serif}
  .panel-subtitle{font:700 9px Quicksand;color:#888}
  .panel-head strong{font:900 14px Quicksand}
  .big-progress{height:9px;background:#eee;border:1.5px solid #171717;border-radius:99px;overflow:hidden}
  .big-progress span{display:block;height:100%;background:#7e9fe7;border-radius:99px}
  .player-count-line{display:flex;justify-content:space-between;gap:10px;margin-top:6px;color:#888;font:700 9px Quicksand}
  .avatars{display:flex;margin-top:14px;padding-left:2px}
  .avatars button,.avatars span{width:31px;height:31px;border:2px solid #171717;border-radius:50%;background:#ffe5d4;display:grid;place-items:center;font:800 10px Quicksand;margin-right:-5px}
  .avatars button.blue{background:#dcecff}.avatars button.peach{background:#ffe5d4}.avatars button.lavender{background:#e9e5ff}.avatars button.mint{background:#ddf3e7}
  .avatars span.empty{background:#fff}
  @media(max-width:360px){.panel{padding:15px}}
</style>
