<script>
  export let name = 'home';
  export let size = 24;
  export let stroke = 2.5;
</script>

<svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width={stroke} stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
  {#if name === 'home'}<path d="M3 10.8 12 3l9 7.8"/><path d="M5.5 9.8V21h13V9.8"/><path d="M9.5 21v-6h5v6"/>
  {:else if name === 'user'}<circle cx="12" cy="7.5" r="3.2"/><path d="M5.5 21c.6-4 2.8-6 6.5-6s5.9 2 6.5 6"/>
  {:else if name === 'bolt'}<path d="m13.5 2-7 11h5l-1 9 7-12h-5z"/>
  {:else if name === 'menu'}<path d="M5 7h14M5 12h14M5 17h14"/>
  {:else if name === 'plus'}<path d="M12 5v14M5 12h14"/>
  {:else if name === 'search'}<circle cx="10.8" cy="10.8" r="6.3"/><path d="m16 16 4.2 4.2"/>
  {:else if name === 'back'}<path d="m15 5-7 7 7 7"/>
  {:else if name === 'map'}<path d="m3 6 6-3 6 3 6-3v15l-6 3-6-3-6 3z"/><path d="M9 3v15M15 6v15"/>
  {:else if name === 'clock'}<circle cx="12" cy="12" r="8.5"/><path d="M12 7v5l3.5 2"/>
  {:else if name === 'calendar'}<rect x="3" y="4.5" width="18" height="17" rx="3"/><path d="M7 2.5v4M17 2.5v4M3 9h18"/>
  {:else if name === 'bell'}<path d="M18 9a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9"/><path d="M10 21h4"/>
  {:else if name === 'chevron'}<path d="m9 5 7 7-7 7"/>
  {:else if name === 'edit'}<path d="m4 20 4.2-.9L19 8.3a2.1 2.1 0 0 0-3-3L5.2 16.1z"/><path d="m14.5 6.5 3 3"/>
  {:else if name === 'close'}<path d="m6 6 12 12M18 6 6 18"/>
  {:else if name === 'message'}<path d="M4 5.5h16v11H8l-4 3z"/>
  {:else if name === 'send'}<path d="m3 11 18-8-5 18-4-7z"/><path d="M12 14 21 3"/>
  {/if}
</svg>
