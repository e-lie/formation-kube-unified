<script>
  export let data;
  const { post } = data;
</script>

<svelte:head>
  <title>{post.metadata.title || post.slug} - Formation Terraform</title>
</svelte:head>

<article class="prose prose-lg max-w-4xl mx-auto p-8">
  <svelte:component this={post.content} />
  
  <div class="mt-12 pt-8 border-t">
    <a href="/blog" class="text-blue-600 hover:text-blue-800">← Retour à la liste des parties</a>
  </div>
</article>