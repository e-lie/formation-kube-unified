<script>
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  
  // Redirection automatique vers la page des tutoriels
  onMount(() => {
    goto('/blog');
  });
</script>

<div class="flex items-center justify-center min-h-screen">
  <div class="text-center">
    <h1 class="text-4xl font-bold mb-4">Formation Terraform</h1>
    <p class="text-xl text-gray-600 mb-8">Redirection vers les tutoriels...</p>
    <a href="/blog" class="text-blue-600 hover:text-blue-800">Accéder aux tutoriels →</a>
  </div>
</div>