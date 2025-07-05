<script>
  import './styles.css';
  import { page } from '$app/stores';
  import { onMount } from 'svelte';
  
  let posts = [];
  let showSidebar = false;
  
  onMount(async () => {
    try {
      // Load posts for navigation
      const response = await fetch('/api/posts');
      posts = await response.json();
    } catch (error) {
      console.error('Failed to load posts:', error);
    }
  });
  
  $: isHomePage = $page.route?.id === '/';
  $: currentSlug = $page.params?.slug;
</script>

<div class="min-h-screen bg-gray-50">
  <!-- Header -->
  <nav class="bg-white shadow-sm sticky top-0 z-40">
    <div class="max-w-7xl mx-auto px-4 py-4">
      <div class="flex justify-between items-center">
        <div class="flex items-center space-x-4">
          {#if !isHomePage}
            <button 
              on:click={() => showSidebar = !showSidebar}
              class="md:hidden p-2 rounded-md hover:bg-gray-100"
              aria-label="Toggle menu"
            >
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            </button>
          {/if}
          <a href="/" class="text-xl font-bold text-gray-900 hover:text-blue-600">Formation Terraform</a>
        </div>
        
        <div class="flex items-center space-x-4">
          <a href="/blog" class="text-blue-600 hover:text-blue-800 font-medium">Tutoriels</a>
        </div>
      </div>
    </div>
  </nav>

  <!-- Layout with sidebar -->
  <div class="flex">
    <!-- Sidebar -->
    {#if !isHomePage}
      <aside class="fixed inset-y-0 left-0 z-30 w-64 bg-white shadow-lg transform transition-transform duration-300 ease-in-out md:translate-x-0 md:static md:inset-0 {showSidebar ? 'translate-x-0' : '-translate-x-full'} top-16 md:top-0">
        <div class="flex flex-col h-full">
          <div class="flex-1 flex flex-col pt-5 pb-4 overflow-y-auto">
            <div class="px-4 mb-4">
              <h2 class="text-lg font-semibold text-gray-900">Sommaire</h2>
            </div>
            
            <nav class="flex-1 px-4 space-y-1">
              {#each posts as post}
                <a 
                  href="/blog/{post.slug}"
                  class="group flex items-center px-3 py-2 text-sm font-medium rounded-md transition-colors {currentSlug === post.slug ? 'bg-blue-100 text-blue-700' : 'text-gray-700 hover:text-gray-900 hover:bg-gray-50'}"
                  on:click={() => showSidebar = false}
                >
                  <span class="truncate">{post.title}</span>
                </a>
              {/each}
            </nav>
          </div>
        </div>
      </aside>

      <!-- Overlay for mobile -->
      {#if showSidebar}
        <div 
          class="fixed inset-0 z-20 bg-black bg-opacity-50 md:hidden"
          on:click={() => showSidebar = false}
        ></div>
      {/if}
    {/if}

    <!-- Main content -->
    <main class="flex-1 {!isHomePage ? 'md:ml-0' : ''} min-h-screen">
      <div class="max-w-5xl mx-auto {!isHomePage ? 'px-6 py-8' : ''}">
        <slot />
      </div>
    </main>
  </div>

  <!-- Footer -->
  <footer class="bg-gray-100 mt-12">
    <div class="max-w-7xl mx-auto px-8 py-6 text-center text-gray-600">
      <p>Formation Terraform - Tutoriels pratiques pour AWS</p>
    </div>
  </footer>
</div>