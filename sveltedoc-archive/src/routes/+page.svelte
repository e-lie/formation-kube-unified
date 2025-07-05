<div class="home">
  <div class="hero">
    <div class="hero-content">
      <h1 class="hero-title">
        Formation <span class="terraform-text">Terraform</span>
      </h1>
      <p class="hero-description">
        Apprenez Terraform étape par étape, de la création d'un serveur simple 
        aux architectures complexes avec modules et gestion d'état avancée.
      </p>
      <div class="hero-actions">
        <a href="/docs" class="btn btn-primary">
          Commencer la formation
        </a>
        <a href="https://terraform.io" class="btn btn-secondary" target="_blank" rel="noopener">
          Documentation Terraform
        </a>
      </div>
    </div>
  </div>
  
  <div class="features">
    <div class="features-grid">
      <div class="feature">
        <div class="feature-icon">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/>
          </svg>
        </div>
        <h3>Progressif</h3>
        <p>9 parties qui s'enchaînent logiquement, de EC2 simple aux modules complexes</p>
      </div>
      
      <div class="feature">
        <div class="feature-icon">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/>
            <polyline points="14,2 14,8 20,8"/>
            <line x1="16" y1="13" x2="8" y2="13"/>
            <line x1="16" y1="17" x2="8" y2="17"/>
            <polyline points="10,9 9,9 8,9"/>
          </svg>
        </div>
        <h3>Pratique</h3>
        <p>Chaque partie inclut du code fonctionnel et des exemples concrets</p>
      </div>
      
      <div class="feature">
        <div class="feature-icon">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M22 12h-4l-3 9L9 3l-3 9H2"/>
          </svg>
        </div>
        <h3>Production Ready</h3>
        <p>Apprenez les bonnes pratiques pour des infrastructures robustes</p>
      </div>
    </div>
  </div>
</div>

<style>
  .home {
    max-width: 1200px;
    margin: 0 auto;
    padding: 2rem 1rem;
  }

  .hero {
    text-align: center;
    padding: 4rem 0 6rem;
  }

  .hero-content {
    max-width: 800px;
    margin: 0 auto;
  }

  .hero-title {
    font-size: 3.5rem;
    font-weight: 700;
    line-height: 1.1;
    margin: 0 0 1.5rem;
    color: var(--sk-text-1);
  }

  .terraform-text {
    color: var(--sk-theme-1);
  }

  .hero-description {
    font-size: 1.25rem;
    line-height: 1.6;
    color: var(--sk-text-2);
    margin: 0 0 2.5rem;
    max-width: 600px;
    margin-left: auto;
    margin-right: auto;
  }

  .hero-actions {
    display: flex;
    gap: 1rem;
    justify-content: center;
    flex-wrap: wrap;
  }

  .btn {
    display: inline-flex;
    align-items: center;
    padding: 0.75rem 1.5rem;
    border-radius: 0.5rem;
    text-decoration: none;
    font-weight: 600;
    font-size: 1rem;
    transition: all 0.2s ease;
    border: 1px solid transparent;
  }

  .btn-primary {
    background: var(--sk-theme-1);
    color: white;
  }

  .btn-primary:hover {
    background: color-mix(in srgb, var(--sk-theme-1) 90%, black);
    transform: translateY(-1px);
  }

  .btn-secondary {
    background: var(--sk-back-3);
    color: var(--sk-text-1);
    border-color: var(--sk-line);
  }

  .btn-secondary:hover {
    background: var(--sk-back-4);
    border-color: var(--sk-text-3);
  }

  .features {
    padding: 2rem 0;
  }

  .features-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 2rem;
    margin-top: 3rem;
  }

  .feature {
    text-align: center;
    padding: 2rem 1.5rem;
    background: var(--sk-back-2);
    border: 1px solid var(--sk-line);
    border-radius: 0.75rem;
    transition: all 0.2s ease;
  }

  .feature:hover {
    border-color: var(--sk-theme-1);
    transform: translateY(-2px);
  }

  .feature-icon {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 3rem;
    height: 3rem;
    background: color-mix(in srgb, var(--sk-theme-1) 10%, transparent);
    color: var(--sk-theme-1);
    border-radius: 0.75rem;
    margin-bottom: 1rem;
  }

  .feature h3 {
    font-size: 1.25rem;
    font-weight: 600;
    margin: 0 0 0.75rem;
    color: var(--sk-text-1);
  }

  .feature p {
    color: var(--sk-text-2);
    line-height: 1.6;
    margin: 0;
  }

  @media (max-width: 768px) {
    .hero-title {
      font-size: 2.5rem;
    }
    
    .hero-description {
      font-size: 1.125rem;
    }
    
    .hero-actions {
      flex-direction: column;
      align-items: center;
    }
    
    .btn {
      min-width: 200px;
    }
  }
</style>
