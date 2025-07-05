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

// Fonction pour découvrir automatiquement les dossiers avec pattern 3 chiffres
function discoverDirectories() {
  const mapping = {};
  
  try {
    const items = readdirSync(SOURCE_DIR, { withFileTypes: true });
    const directories = items.filter(dirent => dirent.isDirectory());
    
    directories.forEach(dir => {
      const dirName = dir.name;
      
      // Pattern pour dossiers commençant par 3 chiffres
      const threeDigitMatch = dirName.match(/^(\d{3})_(.*)/);
      if (threeDigitMatch) {
        const [, digits, name] = threeDigitMatch;
        const dirPath = join(SOURCE_DIR, dirName);
        
        // Chercher le premier fichier markdown dans ce dossier
        try {
          const files = readdirSync(dirPath);
          const markdownFile = files.find(file => file.endsWith('.md'));
          
          if (markdownFile) {
            const sourcePath = `${dirName}/${markdownFile}`;
            const targetPath = `guides/${dirName.toLowerCase().replace(/_/g, '-')}.md`;
            mapping[sourcePath] = targetPath;
          }
        } catch (error) {
          console.warn(`⚠️  Could not read directory ${dirName}:`, error.message);
        }
      }
      
      // Garder le pattern spécial pour partmaybe_vpc_networking
      if (dirName === 'partmaybe_vpc_networking') {
        const dirPath = join(SOURCE_DIR, dirName);
        try {
          const files = readdirSync(dirPath);
          const markdownFile = files.find(file => file.endsWith('.md'));
          
          if (markdownFile) {
            const sourcePath = `${dirName}/${markdownFile}`;
            const targetPath = `guides/${dirName.toLowerCase().replace(/_/g, '-')}.md`;
            mapping[sourcePath] = targetPath;
          }
        } catch (error) {
          console.warn(`⚠️  Could not read directory ${dirName}:`, error.message);
        }
      }
    });
    
    console.log('📁 Discovered directories:', Object.keys(mapping));
    return mapping;
  } catch (error) {
    console.error('❌ Error discovering directories:', error.message);
    return {};
  }
}

// Configuration de mapping des fichiers (généré dynamiquement)
const FILE_MAPPING = discoverDirectories();

// Fonction pour extraire le frontmatter et ajouter les métadonnées Starlight
function processMarkdownContent(content, filename, sourceDirName = '') {
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
  
  // Corriger les chemins d'images
  // Transformer: images/diagram.png → /part4_simple_vpc/images/diagram.png
  if (sourceDirName) {
    bodyContent = bodyContent.replace(
      /!\[([^\]]*)\]\(images\/([^)]+)\)/g,
      `![$1](/${sourceDirName}/images/$2)`
    );
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
    
    // Extraire le nom du dossier source pour les chemins d'images
    const sourceDir = dirname(sourcePath);
    const sourceDirName = basename(sourceDir);
    
    const processedContent = processMarkdownContent(content, basename(sourcePath), sourceDirName);
    
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
  
  // Nettoyer les fichiers markdown orphelins
  if (existsSync(TARGET_DIR)) {
    try {
      const targetFiles = readdirSync(join(TARGET_DIR, 'guides'), { withFileTypes: true })
        .filter(dirent => dirent.isFile() && dirent.name.endsWith('.md'))
        .map(dirent => dirent.name);
      
      const expectedFiles = Object.values(FILE_MAPPING).map(path => basename(path));
      
      targetFiles.forEach(file => {
        if (!expectedFiles.includes(file)) {
          const filePath = join(TARGET_DIR, 'guides', file);
          console.log(`🗑️  Removing orphaned markdown: ${file}`);
          unlinkSync(filePath);
        }
      });
    } catch (error) {
      console.warn('⚠️  Could not clean up markdown files:', error.message);
    }
  }
  
  // Nettoyer les images orphelines - découvrir automatiquement les dossiers d'images
  const imageFolders = [];
  
  // Chercher les dossiers d'images dans tous les dossiers découverts
  Object.keys(FILE_MAPPING).forEach(sourcePath => {
    const dirName = dirname(sourcePath);
    const imageFolder = join(dirName, 'images');
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
  
  // Synchroniser les images - découvrir automatiquement les dossiers d'images
  Object.keys(FILE_MAPPING).forEach(sourcePath => {
    const dirName = dirname(sourcePath);
    const imageFolder = join(dirName, 'images');
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
  
  // Watcher pour les images - découvrir automatiquement les patterns
  const imagePatterns = [];
  Object.keys(FILE_MAPPING).forEach(sourcePath => {
    const dirName = dirname(sourcePath);
    const imagePattern = join(SOURCE_DIR, dirName, 'images/*.{png,jpg,jpeg,gif,svg,webp}');
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