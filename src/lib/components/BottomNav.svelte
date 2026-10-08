<script>
  import Icon from './Icon.svelte';
  export let active = 'home';
  /** @type {(id: string) => void} */
  export let onNavigate = (id) => {};

  const items = [
    { id:'home', label:'Home', icon:'home' },
    { id:'friends', label:'Friends', icon:'user' },
    { id:'stats', label:'Stats', icon:'bolt' },
    { id:'profile', label:'Profile', icon:'menu' }
  ];

  let lastNavigationAt = 0;
  let lastNavigationId = '';

  /** @param {string} id */
  function activate(id) {
    const now = Date.now();
    if (lastNavigationId === id && now - lastNavigationAt < 250) return;
    lastNavigationId = id;
    lastNavigationAt = now;
    onNavigate(id);
  }

  /** @param {PointerEvent} event @param {string} id */
  function handlePointerUp(event, id) {
    if (event.button !== 0) return;
    activate(id);
  }

  /** @param {MouseEvent} event @param {string} id */
  function handleClick(event, id) {
    if (event.button !== 0) return;
    activate(id);
  }

  /** @param {KeyboardEvent} event @param {string} id */
  function handleKeydown(event, id) {
    if (event.key !== 'Enter' && event.key !== ' ') return;
    event.preventDefault();
    activate(id);
  }
</script>
<nav class="nav" aria-label="Primary navigation">
  {#each items as item}
    <button
      type="button"
      class:active={active === item.id}
      aria-label={item.label}
      aria-current={active === item.id ? 'page' : undefined}
      onpointerup={(event) => handlePointerUp(event, item.id)}
      onclick={(event) => handleClick(event, item.id)}
      onkeydown={(event) => handleKeydown(event, item.id)}
    >
      <Icon name={item.icon} size={25} stroke={active === item.id ? 3 : 2.5}/><span>{item.label}</span>
    </button>
  {/each}
</nav>
<style>
  .nav{position:fixed;left:50%;bottom:calc(16px + env(safe-area-inset-bottom));transform:translateX(-50%);width:min(calc(100% - 32px),398px);display:grid;grid-template-columns:repeat(4,1fr);padding:9px;gap:4px;background:#fff;border:2px solid #171717;border-radius:24px;box-shadow:-6px 8px 0 #a1a2a4;z-index:9999;pointer-events:auto;isolation:isolate}
  button{position:relative;z-index:10000;border:0;background:transparent;border-radius:17px;padding:8px 4px 7px;color:#777;display:grid;place-items:center;gap:2px;touch-action:manipulation;-webkit-tap-highlight-color:transparent}
  button.active{color:#171717;background:#efefef}
  span{font:700 11px Quicksand,sans-serif;letter-spacing:.005em;word-spacing:.02em}
</style>
