# Formation Terraform - Documentation

Site de documentation généré avec [Astro Starlight](https://starlight.astro.build/) pour la formation Terraform avec AWS.

[![Built with Starlight](https://astro.badg.es/v2/built-with-starlight/tiny.svg)](https://starlight.astro.build)

## 🚀 Démarrage rapide

```bash
# Installation des dépendances
npm install

# Développement avec hot-reload + file watcher
npm run dev

# Build de production
npm run build

# Preview du build
npm run preview
```

## 📁 Structure

```
doc_starlight/
├── src/
│   ├── content/
│   │   └── docs/
│   │       ├── index.mdx           # Page d'accueil
│   │       └── guides/             # Guides auto-générés
│   │           ├── part1-simple-aws-server.md
│   │           ├── part2-packer-ami.md
│   │           └── ...
│   └── assets/
├── public/                         # Images des TP auto-copiées
│   ├── part4_simple_vpc/
│   ├── part8_count_loadbalancer/
│   └── partmaybe_vpc_networking/
├── sync-docs.js                    # Script de synchronisation
└── astro.config.mjs                # Configuration Astro
```

## 🔄 Synchronisation automatique

Le script `sync-docs.js` synchronise automatiquement :

- **Fichiers markdown** : depuis `../part*/part*.md` → `src/content/docs/guides/`
- **Images** : depuis `../part*/images/*` → `public/part*/images/`

### File watcher

En mode développement (`npm run dev`), le file watcher surveille :
- Les modifications des fichiers markdown sources
- L'ajout/modification d'images
- Synchronisation automatique + hot-reload Astro

### Mapping des fichiers

```javascript
const FILE_MAPPING = {
  'part1_simple_aws_server/part1.md': 'guides/part1-simple-aws-server.md',
  'part2_packer_ami/part2.md': 'guides/part2-packer-ami.md',
  // ... etc
};
```

## 📝 Format des fichiers markdown

### Frontmatter automatique

Le script convertit automatiquement :

```yaml
# Source (part1.md)
---
title: TP partie 1 - server simple avec AWS
weight: 4
---

# → Devient (Starlight)
---
title: "TP partie 1 - server simple avec AWS"
description: "Guide TP partie 1 - server simple avec AWS"
sidebar:
  order: 4
---
```

### Références d'images

Les images sont automatiquement copiées et accessibles via :
```markdown
![Diagram](../../../part4_simple_vpc/images/vpc-simple-diagram.png)
```

## 🛠️ Fonctionnalités Starlight

- **Syntax highlighting** : Shiki intégré avec support HCL/Terraform
- **Navigation automatique** : Basée sur la structure des fichiers
- **Search** : Recherche full-text intégrée
- **Dark mode** : Thème sombre/clair automatique
- **Mobile responsive** : Optimisé pour tous les écrans
- **SEO** : Meta tags et sitemap automatiques

## 📦 Scripts disponibles

- `npm run dev` : Dev server + file watcher
- `npm run sync-docs` : Synchronisation manuelle unique
- `npm run sync-docs:watch` : File watcher seul
- `npm run build` : Build de production
- `npm run preview` : Preview du build

## 🎯 Workflow de développement

1. **Modifier un fichier** dans `../part*/part*.md`
2. **File watcher détecte** → synchronisation automatique
3. **Astro hot-reload** → changements visibles immédiatement
4. **Images** : ajoutées dans `../part*/images/` → copiées automatiquement

Aucune intervention manuelle requise ! 🎉

## 👀 En savoir plus

- [Documentation Starlight](https://starlight.astro.build/)
- [Documentation Astro](https://docs.astro.build)
- [Discord Astro](https://astro.build/chat)