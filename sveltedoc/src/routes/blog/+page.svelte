<script>
  export let data;
  const { posts } = data;
</script>

<svelte:head>
  <title>Formation Terraform - Tutoriels</title>
</svelte:head>

<div class="max-w-4xl mx-auto p-8">
  <h1 class="text-4xl font-bold mb-8">Formation Terraform</h1>
  
  <div class="space-y-6">
    {#each posts as post}
      <div class="border rounded-lg p-6 hover:shadow-lg transition-shadow">
        <h2 class="text-2xl font-semibold mb-2">
          <a href="/blog/{post.slug}" class="text-blue-600 hover:text-blue-800">
            {post.metadata.title || `Partie ${post.slug.match(/\d+/)?.[0] || ''}`}
          </a>
        </h2>
        <p class="text-gray-600">
          {#if post.metadata.weight}
            Difficulté : {post.metadata.weight}/10
          {/if}
        </p>
      </div>
    {/each}
  </div>
</div>