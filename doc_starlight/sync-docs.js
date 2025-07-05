#!/usr/bin/env node

import { readFileSync, writeFileSync, copyFileSync, mkdirSync, existsSync, readdirSync } from 'fs';
import { join, dirname, relative, basename } from 'path';
import { fileURLToPath } from 'url';
import chokidar from 'chokidar';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Chemins
const ROOT_DIR = join(__dirname, '..');
const SOURCE_DIR = ROOT_DIR;
const TARGET_DIR = join(__dirname, 'src/content/docs');
const TARGET_PUBLIC_DIR = join(__dirname, 'public');

// Configuration de mapping des fichiers
const FILE_MAPPING = {
  'part1_simple_aws_server/part1.md': 'guides/part1-simple-aws-server.md',
  'part2_packer_ami/part2.md': 'guides/part2-packer-ami.md', 
  'part3_terraform_provisioner/part3.md': 'guides/part3-terraform-provisioner.md',
  'part4_simple_vpc/part4.md': 'guides/part4-simple-vpc.md',
  'part5_terraform_organization/part5.md': 'guides/part5-terraform-organization.md',
  'part6_terraform_state_workspaces/part6.md': 'guides/part6-terraform-state-workspaces.md',
  'part7_backend_s3/part7.md': 'guides/part7-backend-s3.md',
  'part8_count_loadbalancer/part8.md': 'guides/part8-count-loadbalancer.md',
  'part9_refactorisation_modules/part9.md': 'guides/part9-refactorisation-modules.md',
  'partmaybe_vpc_networking/part7.md': 'guides/partmaybe-vpc-networking.md'
};

// Fonction pour extraire le frontmatter et ajouter les métadonnées Starlight
function processMarkdownContent(content, filename) {
  // Extraire le frontmatter existant s'il y en a un
  const frontmatterMatch = content.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  
  let existingFrontmatter = {};
  let bodyContent = content;
  
  if (frontmatterMatch) {
    const [, frontmatter, body] = frontmatterMatch;
    bodyContent = body;
    
    // Parser le frontmatter YAML basique
    frontmatter.split('\n').forEach(line => {
      const colonIndex = line.indexOf(':');
      if (colonIndex > 0) {
        const key = line.slice(0, colonIndex).trim();
        const value = line.slice(colonIndex + 1).trim();
        existingFrontmatter[key] = isNaN(value) ? value : Number(value);
      }
    });
  }
  
  // Générer un titre par défaut si pas présent
  if (!existingFrontmatter.title) {
    existingFrontmatter.title = filename
      .replace(/\.md$/, '')
      .replace(/part(\d+)[-_]?/, 'TP partie $1 - ')
      .replace(/[-_]/g, ' ')
      .replace(/\b\w/g, l => l.toUpperCase());
  }
  
  // Ajouter des métadonnées Starlight
  const starlightFrontmatter = {
    title: existingFrontmatter.title,
    description: existingFrontmatter.description || `Guide ${existingFrontmatter.title}`,
    sidebar: {
      order: existingFrontmatter.weight || 0
    }
  };
  
  // Créer le nouveau contenu avec le frontmatter Starlight
  const frontmatterYaml = Object.entries(starlightFrontmatter)
    .map(([key, value]) => {
      if (typeof value === 'object') {
        return `${key}:\n${Object.entries(value).map(([k, v]) => `  ${k}: ${v}`).join('\n')}`;
      }
      return `${key}: ${JSON.stringify(value)}`;
    })
    .join('\n');
    
  return `---\n${frontmatterYaml}\n---\n\n${bodyContent}`;
}

// Fonction pour synchroniser un fichier markdown
function syncMarkdownFile(sourcePath, targetPath) {
  try {
    console.log(`📄 Syncing: ${relative(ROOT_DIR, sourcePath)} → ${relative(__dirname, targetPath)}`);
    
    const content = readFileSync(sourcePath, 'utf-8');
    const processedContent = processMarkdownContent(content, basename(sourcePath));
    
    // Créer le répertoire cible si nécessaire
    mkdirSync(dirname(targetPath), { recursive: true });
    
    // Écrire le fichier traité
    writeFileSync(targetPath, processedContent);
    console.log(`✅ Processed markdown: ${basename(targetPath)}`);
  } catch (error) {
    console.error(`❌ Error syncing ${sourcePath}:`, error.message);
  }
}

// Fonction pour synchroniser les images
function syncImageFile(sourcePath, targetPath) {
  try {
    console.log(`🖼️  Syncing image: ${relative(ROOT_DIR, sourcePath)} → ${relative(__dirname, targetPath)}`);
    
    // Créer le répertoire cible si nécessaire
    mkdirSync(dirname(targetPath), { recursive: true });
    
    // Copier l'image
    copyFileSync(sourcePath, targetPath);
    console.log(`✅ Copied image: ${basename(targetPath)}`);
  } catch (error) {
    console.error(`❌ Error syncing image ${sourcePath}:`, error.message);
  }
}

// Fonction pour synchroniser tous les fichiers
function syncAllFiles() {
  console.log('🔄 Syncing all files...');
  
  // Synchroniser les fichiers markdown
  Object.entries(FILE_MAPPING).forEach(([source, target]) => {
    const sourcePath = join(SOURCE_DIR, source);
    const targetPath = join(TARGET_DIR, target);
    
    if (existsSync(sourcePath)) {
      syncMarkdownFile(sourcePath, targetPath);
    }
  });
  
  // Synchroniser les images
  const imageFolders = [
    'part4_simple_vpc/images',
    'part8_count_loadbalancer/images', 
    'partmaybe_vpc_networking/images'
  ];
  
  imageFolders.forEach(folder => {
    const sourceFolder = join(SOURCE_DIR, folder);
    if (existsSync(sourceFolder)) {
      const files = readdirSync(sourceFolder);
      files.forEach(file => {
        if (file.match(/\.(png|jpg|jpeg|gif|svg|webp)$/i)) {
          const sourcePath = join(sourceFolder, file);
          const targetPath = join(TARGET_PUBLIC_DIR, folder, file);
          syncImageFile(sourcePath, targetPath);
        }
      });
    }
  });
  
  console.log('✅ Initial sync completed');
}

// Fonction pour démarrer le file watcher
function startFileWatcher() {
  console.log('🔍 Starting file watcher...');
  
  // Watcher pour les fichiers markdown
  const markdownPaths = Object.keys(FILE_MAPPING).map(path => join(SOURCE_DIR, path));
  const markdownWatcher = chokidar.watch(markdownPaths, {
    persistent: true,
    ignoreInitial: true
  });
  
  // Watcher pour les images
  const imageWatcher = chokidar.watch([
    join(SOURCE_DIR, 'part*/images/*.{png,jpg,jpeg,gif,svg,webp}')
  ], {
    persistent: true,
    ignoreInitial: true
  });
  
  markdownWatcher.on('change', (sourcePath) => {
    const relativePath = relative(SOURCE_DIR, sourcePath);
    const targetPath = join(TARGET_DIR, FILE_MAPPING[relativePath]);
    
    if (targetPath) {
      console.log(`\n📝 File changed: ${relativePath}`);
      syncMarkdownFile(sourcePath, targetPath);
    }
  });
  
  imageWatcher.on('change', (sourcePath) => {
    const relativePath = relative(SOURCE_DIR, sourcePath);
    const targetPath = join(TARGET_PUBLIC_DIR, relativePath);
    
    console.log(`\n🖼️  Image changed: ${relativePath}`);
    syncImageFile(sourcePath, targetPath);
  });
  
  imageWatcher.on('add', (sourcePath) => {
    const relativePath = relative(SOURCE_DIR, sourcePath);
    const targetPath = join(TARGET_PUBLIC_DIR, relativePath);
    
    console.log(`\n🆕 New image: ${relativePath}`);
    syncImageFile(sourcePath, targetPath);
  });
  
  console.log('✅ File watcher started');
  
  return { markdownWatcher, imageWatcher };
}

// Script principal
function main() {
  const args = process.argv.slice(2);
  const watchMode = args.includes('--watch') || args.includes('-w');
  
  console.log('🚀 Starting documentation sync...');
  
  // Synchronisation initiale
  syncAllFiles();
  
  if (watchMode) {
    const watchers = startFileWatcher();
    
    // Gérer la fermeture propre
    process.on('SIGINT', () => {
      console.log('\n🛑 Closing file watchers...');
      watchers.markdownWatcher.close();
      watchers.imageWatcher.close();
      console.log('✅ File watchers closed');
      process.exit(0);
    });
    
    console.log('\n👁️  Watching for changes... (Ctrl+C to stop)');
  } else {
    console.log('✅ Sync completed');
  }
}

// Exporter les fonctions pour usage externe
export { syncAllFiles, startFileWatcher };

// Exécuter si appelé directement
if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}