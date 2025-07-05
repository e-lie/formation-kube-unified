<script>
  let { data } = $props();
  
  const docs = $derived(data.docs);
</script>

<div class="docs-index">
  <div class="docs-header">
    <h1>Formation Terraform</h1>
    <p>Guide complet pour maîtriser Terraform, de la création d'instances EC2 simples aux architectures complexes avec modules.</p>
  </div>

  <div class="docs-grid">
    {#each docs as doc}
      <a href="/docs/{doc.slug}" class="doc-card">
        <div class="doc-card-header">
          <h3>{doc.title}</h3>
        </div>
        <div class="doc-card-content">
          {#if doc.metadata.description}
            <p>{doc.metadata.description}</p>
          {:else}
            <p>Découvrez cette partie de la formation Terraform</p>
          {/if}
        </div>
      </a>
    {/each}
  </div>

  {#if docs.length === 0}
    <div class="empty-state">
      <div class="empty-icon">
        <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
          <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/>
          <polyline points="14,2 14,8 20,8"/>
          <line x1="16" y1="13" x2="8" y2="13"/>
          <line x1="16" y1="17" x2="8" y2="17"/>
          <polyline points="10,9 9,9 8,9"/>
        </svg>
      </div>
      <h3>Aucune documentation trouvée</h3>
      <p>Les fichiers de documentation se synchroniseront automatiquement lors du développement.</p>
    </div>
  {/if}
</div>

<style>
  .docs-index {
    max-width: 1200px;
    margin: 0 auto;
    padding: 2rem 1rem;
  }

  .docs-header {
    text-align: center;
    margin-bottom: 3rem;
    padding-bottom: 2rem;
    border-bottom: 1px solid var(--sk-line);
  }

  .docs-header h1 {
    font-size: 2.5rem;
    font-weight: 700;
    margin: 0 0 1rem;
    color: var(--sk-text-1);
  }

  .docs-header p {
    font-size: 1.125rem;
    color: var(--sk-text-2);
    line-height: 1.6;
    max-width: 600px;
    margin: 0 auto;
  }

  .docs-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
    gap: 1.5rem;
  }

  .doc-card {
    display: block;
    text-decoration: none;
    background: var(--sk-back-2);
    border: 1px solid var(--sk-line);
    border-radius: 0.75rem;
    padding: 1.5rem;
    transition: all 0.2s ease;
    height: fit-content;
  }

  .doc-card:hover {
    border-color: var(--sk-theme-1);
    transform: translateY(-2px);
    box-shadow: 0 4px 12px color-mix(in srgb, var(--sk-theme-1) 15%, transparent);
  }

  .doc-card-header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    margin-bottom: 0.75rem;
    gap: 1rem;
  }

  .doc-card-header h3 {
    font-size: 1.25rem;
    font-weight: 600;
    color: var(--sk-text-1);
    margin: 0;
    line-height: 1.3;
    flex: 1;
  }


  .doc-card-content p {
    color: var(--sk-text-2);
    line-height: 1.5;
    margin: 0;
    font-size: 0.9rem;
  }

  .empty-state {
    text-align: center;
    padding: 4rem 2rem;
    color: var(--sk-text-3);
  }

  .empty-icon {
    margin-bottom: 1rem;
    opacity: 0.5;
  }

  .empty-state h3 {
    font-size: 1.25rem;
    margin: 0 0 0.5rem;
    color: var(--sk-text-2);
  }

  .empty-state p {
    margin: 0;
    line-height: 1.5;
  }

  @media (max-width: 768px) {
    .docs-grid {
      grid-template-columns: 1fr;
    }
    
    .docs-header h1 {
      font-size: 2rem;
    }
  }
</style>