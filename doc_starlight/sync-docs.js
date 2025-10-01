#!/usr/bin/env node

import { readFileSync, writeFileSync, copyFileSync, mkdirSync, existsSync, readdirSync, unlinkSync, rmSync } from 'fs';
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

// Base path pour GitHub Pages (à synchroniser avec astro.config.mjs)
// Avec un domaine custom, pas besoin de base path
const BASE_PATH = process.env.BASE_PATH || '';

// Configuration des sections
const SECTIONS = [
  { 
    name: 'section_kubernetes_principal',
    targetDir: 'kubernetes-principal',
    label: 'Kubernetes Principal'
  },
  { 
    name: 'section_gitops_argocd',
    targetDir: 'gitops-argocd',
    label: 'GitOps & ArgoCD'
  },
  { 
    name: 'section_clusters_onpremise',
    targetDir: 'clusters-onpremise',
    label: 'Clusters On-Premise'
  },
  { 
    name: 'section_statefulness_storage',
    targetDir: 'statefulness-storage',
    label: 'Statefulness & Storage'
  },
  { 
    name: 'section_microservices_istio',
    targetDir: 'microservices-istio',
    label: 'Microservices & Istio'
  },
  { 
    name: 'section_bonus',
    targetDir: 'bonus',
    label: 'Modules Bonus'
  }
];

// Fonction pour découvrir automatiquement les dossiers dans une section
function discoverSectionDirectories(sectionName) {
  const mapping = {};
  const sectionPath = join(SOURCE_DIR, sectionName);
  
  if (!existsSync(sectionPath)) {
    console.log(`⚠️  Section ${sectionName} does not exist yet`);
    return mapping;
  }
  
  try {
    const items = readdirSync(sectionPath, { withFileTypes: true });
    const directories = items.filter(dirent => dirent.isDirectory());
    
    directories.forEach(dir => {
      const dirName = dir.name;
      
      // Pattern pour dossiers commençant par 3 chiffres
      const threeDigitMatch = dirName.match(/^(\d{3})_(.*)/);
      if (threeDigitMatch) {
        const [, digits, name] = threeDigitMatch;
        const dirPath = join(sectionPath, dirName);
        
        // Chercher le premier fichier markdown dans ce dossier
        try {
          const files = readdirSync(dirPath);
          const markdownFile = files.find(file => file.endsWith('.md'));
          
          if (markdownFile) {
            const sourcePath = `${sectionName}/${dirName}/${markdownFile}`;
            // Trouver la section config
            const section = SECTIONS.find(s => s.name === sectionName);
            const targetPath = `${section.targetDir}/${dirName.toLowerCase().replace(/_/g, '-')}.md`;
            mapping[sourcePath] = targetPath;
          }
        } catch (error) {
          console.warn(`⚠️  Could not read directory ${dirName}:`, error.message);
        }
      }
    });
    
    return mapping;
  } catch (error) {
    console.error(`❌ Error discovering directories in ${sectionName}:`, error.message);
    return {};
  }
}

// Fonction pour découvrir tous les dossiers
function discoverAllDirectories() {
  let allMapping = {};
  
  SECTIONS.forEach(section => {
    const sectionMapping = discoverSectionDirectories(section.name);
    allMapping = { ...allMapping, ...sectionMapping };
    if (Object.keys(sectionMapping).length > 0) {
      console.log(`📁 Section ${section.label}:`, Object.keys(sectionMapping).map(p => basename(dirname(p))));
    }
  });
  
  return allMapping;
}

// Configuration de mapping des fichiers (généré dynamiquement)
const FILE_MAPPING = discoverAllDirectories();

// Fonction pour extraire le frontmatter et ajouter les métadonnées Starlight
function processMarkdownContent(content, filename, sourceDirName = '', sectionName = '') {
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
        let value = line.slice(colonIndex + 1).trim();
        
        // Nettoyer les guillemets
        if ((value.startsWith('"') && value.endsWith('"')) || 
            (value.startsWith("'") && value.endsWith("'"))) {
          value = value.slice(1, -1);
        }
        
        // Parser les différents types de valeurs
        if (value === 'true') {
          existingFrontmatter[key] = true;
        } else if (value === 'false') {
          existingFrontmatter[key] = false;
        } else if (!isNaN(value) && value !== '') {
          existingFrontmatter[key] = Number(value);
        } else {
          existingFrontmatter[key] = value;
        }
      }
    });
  }
  
  // Extraire le numéro d'ordre depuis le nom du dossier source
  let orderNumber = 0;
  if (sourceDirName) {
    const threeDigitMatch = sourceDirName.match(/^(\d{3})_/);
    if (threeDigitMatch) {
      orderNumber = parseInt(threeDigitMatch[1], 10);
    }
  }
  
  // Générer un titre par défaut si pas présent
  if (!existingFrontmatter.title) {
    existingFrontmatter.title = filename
      .replace(/\.md$/, '')
      .replace(/part(\d+)[-_]?/, 'TP partie $1 - ')
      .replace(/[-_]/g, ' ')
      .replace(/\b\w/g, l => l.toUpperCase());
  }
  
  // Corriger les chemins d'images
  // Transformer: images/diagram.png → /section_kubernetes_principal/400_simple_vpc/images/diagram.png
  if (sourceDirName && sectionName) {
    bodyContent = bodyContent.replace(
      /!\[([^\]]*)\]\(images\/([^)]+)\)/g,
      `![$1](${BASE_PATH}/${sectionName}/${sourceDirName}/images/$2)`
    );
  }
  
  // Ajouter des métadonnées Starlight
  const starlightFrontmatter = {
    title: existingFrontmatter.title,
    description: existingFrontmatter.description || `Guide ${existingFrontmatter.title}`,
    sidebar: {
      order: orderNumber
    }
  };
  
  // Préserver le champ draft s'il existe
  if (existingFrontmatter.draft !== undefined) {
    starlightFrontmatter.draft = existingFrontmatter.draft;
  }
  
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
    
    // Extraire le nom du dossier source et de la section pour les chemins d'images
    const pathParts = sourcePath.replace(SOURCE_DIR + '/', '').split('/');
    const sectionName = pathParts[0];
    const sourceDirName = pathParts[1];
    
    const processedContent = processMarkdownContent(content, basename(sourcePath), sourceDirName, sectionName);
    
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

// Fonction pour nettoyer les fichiers orphelins
function cleanupOrphanedFiles() {
  console.log('🧹 Cleaning up orphaned files...');
  
  // Nettoyer les fichiers markdown orphelins dans chaque section
  SECTIONS.forEach(section => {
    const sectionTargetDir = join(TARGET_DIR, section.targetDir);
    if (existsSync(sectionTargetDir)) {
      try {
        const targetFiles = readdirSync(sectionTargetDir, { withFileTypes: true })
          .filter(dirent => dirent.isFile() && dirent.name.endsWith('.md'))
          .map(dirent => dirent.name);
        
        const expectedFiles = Object.entries(FILE_MAPPING)
          .filter(([, targetPath]) => targetPath.startsWith(section.targetDir + '/'))
          .map(([, targetPath]) => basename(targetPath));
        
        targetFiles.forEach(file => {
          if (!expectedFiles.includes(file)) {
            const filePath = join(sectionTargetDir, file);
            console.log(`🗑️  Removing orphaned markdown: ${file}`);
            unlinkSync(filePath);
          }
        });
      } catch (error) {
        console.warn(`⚠️  Could not clean up markdown files in ${section.targetDir}:`, error.message);
      }
    }
  });
  
  // Nettoyer les images orphelines
  const imageFolders = [];
  
  // Chercher les dossiers d'images dans tous les dossiers découverts
  Object.keys(FILE_MAPPING).forEach(sourcePath => {
    const pathParts = sourcePath.split('/');
    const sectionName = pathParts[0];
    const dirName = pathParts[1];
    const imageFolder = join(sectionName, dirName, 'images');
    const fullImagePath = join(SOURCE_DIR, imageFolder);
    
    if (existsSync(fullImagePath)) {
      imageFolders.push(imageFolder);
    }
  });
  
  imageFolders.forEach(folder => {
    const targetFolder = join(TARGET_PUBLIC_DIR, folder);
    const sourceFolder = join(SOURCE_DIR, folder);
    
    if (existsSync(targetFolder)) {
      try {
        const targetImages = readdirSync(targetFolder);
        const sourceImages = existsSync(sourceFolder) ? readdirSync(sourceFolder) : [];
        
        targetImages.forEach(image => {
          if (!sourceImages.includes(image)) {
            const imagePath = join(targetFolder, image);
            console.log(`🗑️  Removing orphaned image: ${relative(TARGET_PUBLIC_DIR, imagePath)}`);
            unlinkSync(imagePath);
          }
        });
        
        // Supprimer le dossier s'il est vide
        if (readdirSync(targetFolder).length === 0) {
          console.log(`🗑️  Removing empty folder: ${relative(TARGET_PUBLIC_DIR, targetFolder)}`);
          rmSync(targetFolder, { recursive: true });
        }
      } catch (error) {
        console.warn(`⚠️  Could not clean up images in ${folder}:`, error.message);
      }
    }
  });
}

// Fonction pour synchroniser tous les fichiers
function syncAllFiles() {
  console.log('🔄 Syncing all files...');
  
  // Nettoyer les fichiers orphelins d'abord
  cleanupOrphanedFiles();
  
  // Synchroniser les fichiers markdown
  Object.entries(FILE_MAPPING).forEach(([source, target]) => {
    const sourcePath = join(SOURCE_DIR, source);
    const targetPath = join(TARGET_DIR, target);
    
    if (existsSync(sourcePath)) {
      syncMarkdownFile(sourcePath, targetPath);
    } else {
      console.log(`⚠️  Source file not found: ${source}`);
    }
  });
  
  // Synchroniser les images
  Object.keys(FILE_MAPPING).forEach(sourcePath => {
    const pathParts = sourcePath.split('/');
    const sectionName = pathParts[0];
    const dirName = pathParts[1];
    const imageFolder = join(sectionName, dirName, 'images');
    const fullImagePath = join(SOURCE_DIR, imageFolder);
    
    if (existsSync(fullImagePath)) {
      const files = readdirSync(fullImagePath);
      files.forEach(file => {
        if (file.match(/\.(png|jpg|jpeg|gif|svg|webp)$/i)) {
          const sourceImagePath = join(fullImagePath, file);
          const targetImagePath = join(TARGET_PUBLIC_DIR, imageFolder, file);
          syncImageFile(sourceImagePath, targetImagePath);
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
  const imagePatterns = [];
  Object.keys(FILE_MAPPING).forEach(sourcePath => {
    const pathParts = sourcePath.split('/');
    const sectionName = pathParts[0];
    const dirName = pathParts[1];
    const imagePattern = join(SOURCE_DIR, sectionName, dirName, 'images/*.{png,jpg,jpeg,gif,svg,webp}');
    imagePatterns.push(imagePattern);
  });
  
  const imageWatcher = chokidar.watch(imagePatterns, {
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
  
  markdownWatcher.on('unlink', (sourcePath) => {
    const relativePath = relative(SOURCE_DIR, sourcePath);
    const targetPath = join(TARGET_DIR, FILE_MAPPING[relativePath]);
    
    if (targetPath && existsSync(targetPath)) {
      console.log(`\n🗑️  File removed: ${relativePath}`);
      unlinkSync(targetPath);
      console.log(`✅ Removed target file: ${relative(__dirname, targetPath)}`);
    }
  });

  imageWatcher.on('add', (sourcePath) => {
    const relativePath = relative(SOURCE_DIR, sourcePath);
    const targetPath = join(TARGET_PUBLIC_DIR, relativePath);
    
    console.log(`\n🆕 New image: ${relativePath}`);
    syncImageFile(sourcePath, targetPath);
  });

  imageWatcher.on('unlink', (sourcePath) => {
    const relativePath = relative(SOURCE_DIR, sourcePath);
    const targetPath = join(TARGET_PUBLIC_DIR, relativePath);
    
    if (existsSync(targetPath)) {
      console.log(`\n🗑️  Image removed: ${relativePath}`);
      unlinkSync(targetPath);
      console.log(`✅ Removed target image: ${relative(__dirname, targetPath)}`);
      
      // Supprimer le dossier parent s'il est vide
      const parentDir = dirname(targetPath);
      try {
        if (readdirSync(parentDir).length === 0) {
          console.log(`🗑️  Removing empty folder: ${relative(TARGET_PUBLIC_DIR, parentDir)}`);
          rmSync(parentDir, { recursive: true });
        }
      } catch (error) {
        // Ignore errors when checking/removing parent directory
      }
    }
  });
  
  console.log('✅ File watcher started');
  
  return { markdownWatcher, imageWatcher };
}

// Script principal
function main() {
  const args = process.argv.slice(2);
  const watchMode = args.includes('--watch') || args.includes('-w');
  
  console.log('🚀 Starting documentation sync...');
  console.log('📚 Configured sections:', SECTIONS.map(s => s.label).join(', '));
  
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