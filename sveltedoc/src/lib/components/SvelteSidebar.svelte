<script>
  import { page } from '$app/stores';
  import { onMount } from 'svelte';
  
  let { docs = [], isOpen = false, closeSidebar = () => {} } = $props();
  
  let sidebarElement;
  
  const currentSlug = $derived($page.params?.slug);
  
  // Close sidebar on navigation (mobile)
  $effect(() => {
    if (currentSlug) {
      closeSidebar();
    }
  });
  
  // Handle click outside (mobile)
  onMount(() => {
    function handleClickOutside(event) {
      if (sidebarElement && !sidebarElement.contains(event.target) && isOpen) {
        closeSidebar();
      }
    }
    
    document.addEventListener('click', handleClickOutside);
    return () => document.removeEventListener('click', handleClickOutside);
  });
</script>

<!-- Mobile overlay -->
{#if isOpen}
  <div class="overlay lg:hidden" on:click={closeSidebar} role="button" tabindex="-1"></div>
{/if}

<!-- Sidebar -->
<aside 
  bind:this={sidebarElement}
  class="sidebar"
  class:open={isOpen}
>
  <div class="sidebar-content">
    <nav class="sidebar-nav">
      <div class="nav-section">
        <h3 class="nav-title">Formation Terraform</h3>
        
        <div class="nav-items">
          {#each docs as doc}
            <a 
              href="/docs/{doc.slug}"
              class="nav-item"
              class:active={currentSlug === doc.slug}
            >
              <span class="nav-item-title">{doc.title}</span>
            </a>
          {/each}
        </div>
      </div>
      
      <!-- Additional sections can go here -->
      <div class="nav-section">
        <h3 class="nav-title">Ressources</h3>
        <div class="nav-items">
          <a href="https://terraform.io" class="nav-item external" target="_blank" rel="noopener">
            <span class="nav-item-title">Terraform.io</span>
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M18 13v6a2 2 0 01-2 2H5a2 2 0 01-2-2V8a2 2 0 012-2h6M15 3h6v6M10 14L21 3"/>
            </svg>
          </a>
          <a href="https://aws.amazon.com" class="nav-item external" target="_blank" rel="noopener">
            <span class="nav-item-title">AWS Documentation</span>
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M18 13v6a2 2 0 01-2 2H5a2 2 0 01-2-2V8a2 2 0 012-2h6M15 3h6v6M10 14L21 3"/>
            </svg>
          </a>
        </div>
      </div>
    </nav>
  </div>
</aside>

<style>
  .overlay {
    position: fixed;
    inset: 0;
    z-index: 30;
    background: rgba(0, 0, 0, 0.5);
    backdrop-filter: blur(2px);
  }
  
  .sidebar {
    position: fixed;
    top: var(--header-height);
    left: 0;
    bottom: 0;
    width: var(--sidebar-width);
    z-index: 35;
    background: var(--sk-back-2);
    border-right: 1px solid var(--sk-line);
    transform: translateX(-100%);
    transition: transform 0.3s ease;
    overflow: hidden;
  }
  
  .sidebar.open {
    transform: translateX(0);
  }
  
  .sidebar-content {
    height: 100%;
    overflow-y: auto;
    overflow-x: hidden;
    padding: 1.5rem 0;
    scrollbar-width: thin;
    scrollbar-color: var(--sk-line) transparent;
  }
  
  .sidebar-content::-webkit-scrollbar {
    width: 6px;
  }
  
  .sidebar-content::-webkit-scrollbar-track {
    background: transparent;
  }
  
  .sidebar-content::-webkit-scrollbar-thumb {
    background: var(--sk-line);
    border-radius: 3px;
  }
  
  .sidebar-nav {
    display: flex;
    flex-direction: column;
    gap: 2rem;
  }
  
  .nav-section {
    padding: 0 1.5rem;
  }
  
  .nav-title {
    margin: 0 0 1rem 0;
    font-size: 0.75rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--sk-text-3);
  }
  
  .nav-items {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }
  
  .nav-item {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.5rem 0.75rem;
    text-decoration: none;
    color: var(--sk-text-2);
    font-size: 0.875rem;
    font-weight: 400;
    border-radius: 0.375rem;
    transition: all 0.15s ease;
    border-left: 2px solid transparent;
  }
  
  .nav-item:hover {
    color: var(--sk-text-1);
    background: var(--sk-back-3);
  }
  
  .nav-item.active {
    color: var(--sk-theme-1);
    background: color-mix(in srgb, var(--sk-theme-1) 8%, transparent);
    border-left-color: var(--sk-theme-1);
    font-weight: 500;
  }
  
  .nav-item-title {
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  
  
  .nav-item.external svg {
    opacity: 0.5;
    margin-left: 0.5rem;
  }
  
  @media (min-width: 1024px) {
    .overlay {
      display: none;
    }
    
    .sidebar {
      position: sticky;
      transform: translateX(0);
      top: var(--header-height);
      height: calc(100vh - var(--header-height));
    }
  }
</style>