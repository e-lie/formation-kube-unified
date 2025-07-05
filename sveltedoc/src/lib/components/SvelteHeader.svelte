<script>
  import { page } from '$app/stores';
  
  let { toggleSidebar = () => {} } = $props();
  
  const isDocsPage = $derived($page.url.pathname.startsWith('/docs'));
</script>

<header class="header">
  <div class="header-content">
    <div class="header-left">
      {#if isDocsPage}
        <button 
          class="sidebar-toggle lg:hidden"
          on:click={toggleSidebar}
          aria-label="Toggle sidebar"
        >
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M3 12h18M3 6h18M3 18h18"/>
          </svg>
        </button>
      {/if}
      
      <a href="/" class="logo">
        <svg width="32" height="32" viewBox="0 0 24 24" fill="none">
          <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5" 
                stroke="var(--sk-theme-1)" 
                stroke-width="2" 
                stroke-linecap="round" 
                stroke-linejoin="round"/>
        </svg>
        <span class="logo-text">Formation Terraform</span>
      </a>
    </div>
    
    <nav class="header-nav">
      <a 
        href="/docs" 
        class="nav-link"
        class:active={isDocsPage}
      >
        Documentation
      </a>
      <a href="https://github.com" class="nav-link external" target="_blank" rel="noopener">
        GitHub
        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M18 13v6a2 2 0 01-2 2H5a2 2 0 01-2-2V8a2 2 0 012-2h6M15 3h6v6M10 14L21 3"/>
        </svg>
      </a>
    </nav>
  </div>
</header>

<style>
  .header {
    position: sticky;
    top: 0;
    z-index: 40;
    height: var(--header-height);
    background: var(--sk-back-1);
    border-bottom: 1px solid var(--sk-line);
    backdrop-filter: blur(8px);
  }
  
  .header-content {
    display: flex;
    align-items: center;
    justify-content: space-between;
    height: 100%;
    padding: 0 1rem;
    max-width: none;
  }
  
  .header-left {
    display: flex;
    align-items: center;
    gap: 1rem;
  }
  
  .sidebar-toggle {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 2.5rem;
    height: 2.5rem;
    border: none;
    background: none;
    border-radius: 0.375rem;
    cursor: pointer;
    color: var(--sk-text-2);
    transition: all 0.15s ease;
  }
  
  .sidebar-toggle:hover {
    background: var(--sk-back-3);
    color: var(--sk-text-1);
  }
  
  .logo {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    text-decoration: none;
    color: var(--sk-text-1);
    font-weight: 600;
    font-size: 1.125rem;
  }
  
  .logo:hover {
    color: var(--sk-theme-1);
  }
  
  .logo-text {
    font-weight: 600;
  }
  
  .header-nav {
    display: flex;
    align-items: center;
    gap: 1.5rem;
  }
  
  .nav-link {
    display: flex;
    align-items: center;
    gap: 0.25rem;
    padding: 0.5rem 0.75rem;
    text-decoration: none;
    color: var(--sk-text-2);
    font-size: 0.875rem;
    font-weight: 500;
    border-radius: 0.375rem;
    transition: all 0.15s ease;
  }
  
  .nav-link:hover {
    color: var(--sk-text-1);
    background: var(--sk-back-3);
  }
  
  .nav-link.active {
    color: var(--sk-theme-1);
    background: color-mix(in srgb, var(--sk-theme-1) 10%, transparent);
  }
  
  .nav-link.external svg {
    opacity: 0.6;
  }
  
  @media (min-width: 1024px) {
    .sidebar-toggle {
      display: none;
    }
  }
</style>