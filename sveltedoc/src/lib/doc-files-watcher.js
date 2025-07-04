import chokidar from 'chokidar';
import { readFileSync, writeFileSync, copyFileSync, existsSync, mkdirSync } from 'fs';
import { join, dirname, basename, extname, relative } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Chemins de base
const PROJECT_ROOT = join(__dirname, '../../..');
const SVELTE_STATIC = join(__dirname, '../../static');
const POSTS_DIR = join(__dirname, 'posts');

/**
 * Surveille et synchronise les fichiers markdown et images du projet
 */
export class DocFilesWatcher {
  constructor() {
    this.watcher = null;
    this.isWatching = false;
  }

  /**
   * Démarre la surveillance des fichiers
   */
  async start() {
    if (this.isWatching) return;

    console.log('🔍 Starting markdown files watcher...');
    
    // Initial sync
    await this.syncAllFiles();

    // Watch patterns
    const watchPatterns = [
      join(PROJECT_ROOT, 'part*/part*.md'),
      join(PROJECT_ROOT, 'part*/images/**/*.{png,jpg,jpeg,svg,mmd}'),
      join(PROJECT_ROOT, 'partmaybe*/part*.md'),
      join(PROJECT_ROOT, 'partmaybe*/images/**/*.{png,jpg,jpeg,svg,mmd}')
    ];

    this.watcher = chokidar.watch(watchPatterns, {
      ignored: [
        '**/node_modules/**',
        '**/sveltedoc/**',
        '**/.git/**'
      ],
      persistent: true,
      ignoreInitial: false
    });

    this.watcher
      .on('add', (path) => this.handleFileChange(path, 'added'))
      .on('change', (path) => this.handleFileChange(path, 'changed'))
      .on('unlink', (path) => this.handleFileChange(path, 'removed'))
      .on('error', (error) => console.error('Watcher error:', error));

    this.isWatching = true;
    console.log('✅ Markdown files watcher started');
  }

  /**
   * Arrête la surveillance
   */
  stop() {
    if (this.watcher) {
      this.watcher.close();
      this.watcher = null;
    }
    this.isWatching = false;
    console.log('🛑 Markdown files watcher stopped');
  }

  /**
   * Synchronisation initiale de tous les fichiers
   */
  async syncAllFiles() {
    console.log('🔄 Syncing all markdown and image files...');
    
    // Ensure directories exist
    if (!existsSync(POSTS_DIR)) {
      mkdirSync(POSTS_DIR, { recursive: true });
    }
    if (!existsSync(SVELTE_STATIC)) {
      mkdirSync(SVELTE_STATIC, { recursive: true });
    }

    // Sync markdown files
    await this.syncMarkdownFiles();
    
    // Sync image files
    await this.syncImageFiles();
    
    console.log('✅ Initial sync completed');
  }

  /**
   * Synchronise tous les fichiers markdown
   */
  async syncMarkdownFiles() {
    const { globSync } = await import('glob');
    const markdownFiles = globSync(join(PROJECT_ROOT, 'part*/part*.md'));
    const partmaybeFiles = globSync(join(PROJECT_ROOT, 'partmaybe*/part*.md'));
    
    [...markdownFiles, ...partmaybeFiles].forEach(file => {
      this.processMarkdownFile(file);
    });
  }

  /**
   * Synchronise tous les fichiers d'images
   */
  async syncImageFiles() {
    const { globSync } = await import('glob');
    const imageFiles = globSync(join(PROJECT_ROOT, 'part*/images/**/*.{png,jpg,jpeg,svg,mmd}'));
    const partmaybeImageFiles = globSync(join(PROJECT_ROOT, 'partmaybe*/images/**/*.{png,jpg,jpeg,svg,mmd}'));
    
    [...imageFiles, ...partmaybeImageFiles].forEach(file => {
      this.processImageFile(file);
    });
  }

  /**
   * Gère les changements de fichiers
   */
  handleFileChange(filePath, event) {
    console.log(`📝 File ${event}: ${relative(PROJECT_ROOT, filePath)}`);

    if (filePath.endsWith('.md')) {
      this.processMarkdownFile(filePath);
    } else if (this.isImageFile(filePath)) {
      this.processImageFile(filePath);
    }
  }

  /**
   * Traite un fichier markdown
   */
  processMarkdownFile(filePath) {
    try {
      const content = readFileSync(filePath, 'utf-8');
      const partName = this.extractPartName(filePath);
      
      if (!partName) return;

      // Update image paths in markdown content
      const updatedContent = this.updateImagePaths(content, partName);
      
      // Write to posts directory
      const outputPath = join(POSTS_DIR, `${partName}.md`);
      writeFileSync(outputPath, updatedContent, 'utf-8');
      
      console.log(`✅ Processed markdown: ${partName}.md`);
    } catch (error) {
      console.error(`❌ Error processing markdown ${filePath}:`, error);
    }
  }

  /**
   * Traite un fichier d'image
   */
  processImageFile(filePath) {
    try {
      const partName = this.extractPartNameFromImagePath(filePath);
      if (!partName) return;

      const fileName = basename(filePath);
      const targetDir = join(SVELTE_STATIC, partName);
      
      // Ensure target directory exists
      if (!existsSync(targetDir)) {
        mkdirSync(targetDir, { recursive: true });
      }

      const targetPath = join(targetDir, fileName);
      copyFileSync(filePath, targetPath);
      
      console.log(`✅ Copied image: ${partName}/${fileName}`);
    } catch (error) {
      console.error(`❌ Error processing image ${filePath}:`, error);
    }
  }

  /**
   * Extrait le nom de la partie depuis le chemin du fichier
   */
  extractPartName(filePath) {
    const match = filePath.match(/\/(part\d+[^\/]*|partmaybe[^\/]*)\//);
    return match ? match[1] : null;
  }

  /**
   * Extrait le nom de la partie depuis le chemin d'une image
   */
  extractPartNameFromImagePath(filePath) {
    const match = filePath.match(/\/(part\d+[^\/]*|partmaybe[^\/]*)\/images\//);
    return match ? match[1] : null;
  }

  /**
   * Met à jour les chemins d'images dans le contenu markdown
   */
  updateImagePaths(content, partName) {
    // Replace image paths from images/filename to /partX/filename
    return content.replace(/!\[([^\]]*)\]\(images\/([^)]+)\)/g, (match, alt, filename) => {
      return `![${alt}](/${partName}/${filename})`;
    });
  }

  /**
   * Vérifie si un fichier est une image
   */
  isImageFile(filePath) {
    const ext = extname(filePath).toLowerCase();
    return ['.png', '.jpg', '.jpeg', '.svg', '.mmd'].includes(ext);
  }
}

// Instance singleton
export const docWatcher = new DocFilesWatcher();