<script>
  import { onMount } from 'svelte';
  import { browser } from '$app/environment';
  import { page } from '$app/stores';
  import SvelteHeader from '$lib/components/SvelteHeader.svelte';
  import SvelteSidebar from '$lib/components/SvelteSidebar.svelte';
  import { loadDocs } from '$lib/docs.js';
  import { fileWatcher } from '$lib/file-watcher.js';
  import '../app.css';

  let { children } = $props();
  let docs = [];
  let sidebarOpen = false;

  // Load docs
  onMount(async () => {
    if (browser) {
      // Start file watcher in development
      if (import.meta.env.DEV) {
        try {
          await fileWatcher.start();
        } catch (error) {
          console.warn('File watcher not available:', error);
        }
      }
      
      // Load documentation
      docs = loadDocs();
    }
  });

  // Reactive updates
  const isDocsPage = $derived($page.url.pathname.startsWith('/docs'));

  // Sidebar controls
  function toggleSidebar() {
    sidebarOpen = !sidebarOpen;
  }

  function closeSidebar() {
    sidebarOpen = false;
  }

  // Close sidebar on escape key
  function handleKeydown(event) {
    if (event.key === 'Escape' && sidebarOpen) {
      closeSidebar();
    }
  }
</script>

<svelte:window on:keydown={handleKeydown} />

<div class="app">
  <SvelteHeader {toggleSidebar} />
  
  <div class="app-body">
    {#if isDocsPage}
      <SvelteSidebar {docs} isOpen={sidebarOpen} {closeSidebar} />
    {/if}
    
    <main class="main-content" class:with-sidebar={isDocsPage}>
      {@render children()}
    </main>
  </div>
</div>

<style>
  .app {
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    background: var(--sk-back-1);
    color: var(--sk-text-1);
  }

  .app-body {
    display: flex;
    flex: 1;
    position: relative;
  }

  .main-content {
    flex: 1;
    min-width: 0;
    padding: 0;
    transition: all 0.3s ease;
  }

  .main-content.with-sidebar {
    margin-left: 0;
  }

  @media (min-width: 1024px) {
    .main-content.with-sidebar {
      margin-left: var(--sidebar-width);
    }
  }
</style>
