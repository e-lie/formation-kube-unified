<script>
  export let data;
  const { post } = data;
</script>

<svelte:head>
  <title>{post.title} - Formation Terraform</title>
</svelte:head>

<article class="prose prose-lg max-w-none">
  <div class="bg-white rounded-lg shadow-sm p-8">
    <h1 class="text-3xl font-bold mb-6 text-gray-900 border-b pb-4">{post.title}</h1>
    <div class="prose-content">
      {@html post.html}
    </div>
    
    <div class="mt-12 pt-8 border-t flex justify-between items-center">
      <a href="/blog" class="text-blue-600 hover:text-blue-800 font-medium">
        ← Retour aux tutoriels
      </a>
      
      <div class="text-sm text-gray-500">
        Partie {post.weight} de la formation
      </div>
    </div>
  </div>
</article>

<style>
  :global(.prose-content h1) {
    display: none; /* Hide duplicate h1 from markdown */
  }
  
  :global(.prose-content h2) {
    @apply text-2xl font-semibold mt-8 mb-4 text-gray-800 border-b border-gray-200 pb-2;
  }
  
  :global(.prose-content h3) {
    @apply text-xl font-semibold mt-6 mb-3 text-gray-800;
  }
  
  :global(.prose-content p) {
    @apply mb-4 leading-7 text-gray-700;
  }
  
  :global(.prose-content ul, .prose-content ol) {
    @apply mb-4 ml-6;
  }
  
  :global(.prose-content li) {
    @apply mb-2;
  }
  
  :global(.prose-content pre) {
    @apply bg-gray-900 text-gray-100 p-4 rounded-lg overflow-x-auto mb-4;
  }
  
  :global(.prose-content code) {
    @apply bg-gray-100 text-gray-800 px-2 py-1 rounded text-sm;
  }
  
  :global(.prose-content pre code) {
    @apply bg-transparent text-gray-100 p-0;
  }
  
  :global(.prose-content img) {
    @apply rounded-lg shadow-md mx-auto my-6;
  }
  
  :global(.prose-content blockquote) {
    @apply border-l-4 border-blue-400 pl-4 italic text-gray-600 my-4;
  }
  
  :global(.prose-content table) {
    @apply w-full border-collapse border border-gray-300 my-4;
  }
  
  :global(.prose-content th, .prose-content td) {
    @apply border border-gray-300 px-4 py-2;
  }
  
  :global(.prose-content th) {
    @apply bg-gray-100 font-semibold;
  }
</style>