<script>
  let { data } = $props();
  
  const doc = $derived(data.doc);
</script>

<svelte:head>
  <title>{doc?.title || 'Documentation'} - Formation Terraform</title>
  {#if doc?.metadata?.description}
    <meta name="description" content={doc.metadata.description} />
  {/if}
</svelte:head>

{#if doc}
  <article class="doc-article">
    <header class="doc-header">
      <div class="doc-meta">
        {#if doc.weight && doc.weight < 100}
          <span class="doc-badge">Partie {doc.weight}</span>
        {/if}
      </div>
      <h1 class="doc-title">{doc.title}</h1>
      {#if doc.metadata.description}
        <p class="doc-description">{doc.metadata.description}</p>
      {/if}
    </header>

    <div class="doc-content">
      {@html doc.html}
    </div>

    <footer class="doc-footer">
      <div class="doc-navigation">
        {#if data.prevDoc}
          <a href="/docs/{data.prevDoc.slug}" class="nav-link nav-prev">
            <span class="nav-label">Précédent</span>
            <span class="nav-title">{data.prevDoc.title}</span>
          </a>
        {/if}
        
        {#if data.nextDoc}
          <a href="/docs/{data.nextDoc.slug}" class="nav-link nav-next">
            <span class="nav-label">Suivant</span>
            <span class="nav-title">{data.nextDoc.title}</span>
          </a>
        {/if}
      </div>
    </footer>
  </article>
{:else}
  <div class="doc-not-found">
    <h1>Document non trouvé</h1>
    <p>Le document demandé n'existe pas ou n'a pas encore été synchronisé.</p>
    <a href="/docs" class="back-link">← Retour à la documentation</a>
  </div>
{/if}

<style>
  .doc-article {
    max-width: 800px;
    margin: 0 auto;
    padding: 2rem 1rem;
  }

  .doc-header {
    margin-bottom: 3rem;
    padding-bottom: 2rem;
    border-bottom: 1px solid var(--sk-line);
  }

  .doc-meta {
    margin-bottom: 1rem;
  }

  .doc-badge {
    font-size: 0.75rem;
    color: var(--sk-theme-1);
    background: color-mix(in srgb, var(--sk-theme-1) 10%, transparent);
    padding: 0.25rem 0.5rem;
    border-radius: 0.25rem;
    font-weight: 500;
  }

  .doc-title {
    font-size: 2.5rem;
    font-weight: 700;
    line-height: 1.2;
    margin: 0;
    color: var(--sk-text-1);
  }

  .doc-description {
    font-size: 1.125rem;
    color: var(--sk-text-2);
    line-height: 1.6;
    margin: 1rem 0 0;
  }

  .doc-content {
    line-height: 1.7;
    color: var(--sk-text-1);
  }

  /* Markdown content styling */
  .doc-content :global(h1),
  .doc-content :global(h2),
  .doc-content :global(h3),
  .doc-content :global(h4),
  .doc-content :global(h5),
  .doc-content :global(h6) {
    color: var(--sk-text-1);
    font-weight: 600;
    margin: 2rem 0 1rem;
    line-height: 1.3;
  }

  .doc-content :global(h1) { font-size: 2rem; }
  .doc-content :global(h2) { font-size: 1.5rem; }
  .doc-content :global(h3) { font-size: 1.25rem; }
  .doc-content :global(h4) { font-size: 1.125rem; }

  .doc-content :global(p) {
    margin: 1rem 0;
  }

  .doc-content :global(ul),
  .doc-content :global(ol) {
    margin: 1rem 0;
    padding-left: 1.5rem;
  }

  .doc-content :global(li) {
    margin: 0.5rem 0;
  }

  .doc-content :global(pre) {
    background: var(--sk-back-3);
    border: 1px solid var(--sk-line);
    border-radius: 0.5rem;
    padding: 1rem;
    overflow-x: auto;
    margin: 1.5rem 0;
    font-size: 0.875rem;
  }

  .doc-content :global(code) {
    background: var(--sk-back-3);
    color: var(--sk-text-1);
    padding: 0.125rem 0.25rem;
    border-radius: 0.25rem;
    font-size: 0.875rem;
    font-family: 'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace;
  }

  .doc-content :global(pre code) {
    background: none;
    padding: 0;
    border-radius: 0;
  }

  .doc-content :global(blockquote) {
    border-left: 4px solid var(--sk-theme-1);
    padding-left: 1rem;
    margin: 1.5rem 0;
    color: var(--sk-text-2);
    font-style: italic;
  }

  .doc-content :global(a) {
    color: var(--sk-theme-1);
    text-decoration: none;
  }

  .doc-content :global(a:hover) {
    text-decoration: underline;
  }

  .doc-content :global(img) {
    max-width: 100%;
    height: auto;
    border-radius: 0.5rem;
    margin: 1.5rem 0;
  }

  .doc-content :global(table) {
    width: 100%;
    border-collapse: collapse;
    margin: 1.5rem 0;
    border: 1px solid var(--sk-line);
    border-radius: 0.5rem;
    overflow: hidden;
  }

  .doc-content :global(th),
  .doc-content :global(td) {
    padding: 0.75rem;
    text-align: left;
    border-bottom: 1px solid var(--sk-line);
  }

  .doc-content :global(th) {
    background: var(--sk-back-2);
    font-weight: 600;
  }

  .doc-footer {
    margin-top: 4rem;
    padding-top: 2rem;
    border-top: 1px solid var(--sk-line);
  }

  .doc-navigation {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1rem;
  }

  .nav-link {
    display: flex;
    flex-direction: column;
    padding: 1rem;
    background: var(--sk-back-2);
    border: 1px solid var(--sk-line);
    border-radius: 0.5rem;
    text-decoration: none;
    transition: all 0.2s ease;
  }

  .nav-link:hover {
    border-color: var(--sk-theme-1);
    transform: translateY(-1px);
  }

  .nav-prev {
    text-align: left;
  }

  .nav-next {
    text-align: right;
    grid-column: 2;
  }

  .nav-label {
    font-size: 0.75rem;
    color: var(--sk-text-3);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    margin-bottom: 0.25rem;
  }

  .nav-title {
    font-weight: 500;
    color: var(--sk-text-1);
    line-height: 1.3;
  }

  .doc-not-found {
    max-width: 600px;
    margin: 4rem auto;
    text-align: center;
    padding: 2rem;
  }

  .doc-not-found h1 {
    font-size: 2rem;
    color: var(--sk-text-1);
    margin-bottom: 1rem;
  }

  .doc-not-found p {
    color: var(--sk-text-2);
    margin-bottom: 2rem;
    line-height: 1.6;
  }

  .back-link {
    color: var(--sk-theme-1);
    text-decoration: none;
    font-weight: 500;
  }

  .back-link:hover {
    text-decoration: underline;
  }

  @media (max-width: 768px) {
    .doc-title {
      font-size: 2rem;
    }
    
    .doc-navigation {
      grid-template-columns: 1fr;
    }
    
    .nav-next {
      grid-column: 1;
      text-align: left;
    }
  }
</style>