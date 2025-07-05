import chokidar from 'chokidar';
import { readFileSync, writeFileSync, copyFileSync, existsSync, mkdirSync } from 'fs';
import { join, dirname, basename, extname, relative } from 'path';
import { fileURLToPath } from 'url';
import { globSync } from 'glob';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Paths
const PROJECT_ROOT = join(__dirname, '../../..');
const STATIC_DIR = join(__dirname, '../../static');
const DOCS_DIR = join(__dirname, '../docs');

/**
 * File watcher for syncing markdown docs and images
 */
export class FileWatcher {
  constructor() {
    this.watcher = null;
    this.isWatching = false;
  }

  /**
   * Start watching files
   */
  async start() {
    if (this.isWatching) return;

    console.log('🔍 Starting file watcher...');
    
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
    console.log('✅ File watcher started');
  }

  /**
   * Stop watching
   */
  stop() {
    if (this.watcher) {
      this.watcher.close();
      this.watcher = null;
    }
    this.isWatching = false;
    console.log('🛑 File watcher stopped');
  }

  /**
   * Sync all files initially
   */
  async syncAllFiles() {
    console.log('🔄 Syncing all files...');
    
    // Ensure directories exist
    if (!existsSync(DOCS_DIR)) {
      mkdirSync(DOCS_DIR, { recursive: true });
    }
    if (!existsSync(STATIC_DIR)) {
      mkdirSync(STATIC_DIR, { recursive: true });
    }

    // Sync markdown files
    await this.syncMarkdownFiles();
    
    // Sync image files
    await this.syncImageFiles();
    
    console.log('✅ Initial sync completed');
  }

  /**
   * Sync all markdown files
   */
  async syncMarkdownFiles() {
    const markdownFiles = globSync(join(PROJECT_ROOT, 'part*/part*.md'));
    const partmaybeFiles = globSync(join(PROJECT_ROOT, 'partmaybe*/part*.md'));
    
    [...markdownFiles, ...partmaybeFiles].forEach(file => {
      this.processMarkdownFile(file);
    });
  }

  /**
   * Sync all image files
   */
  async syncImageFiles() {
    const imageFiles = globSync(join(PROJECT_ROOT, 'part*/images/**/*.{png,jpg,jpeg,svg,mmd}'));
    const partmaybeImageFiles = globSync(join(PROJECT_ROOT, 'partmaybe*/images/**/*.{png,jpg,jpeg,svg,mmd}'));
    
    [...imageFiles, ...partmaybeImageFiles].forEach(file => {
      this.processImageFile(file);
    });
  }

  /**
   * Handle file changes
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
   * Process a markdown file
   */
  processMarkdownFile(filePath) {
    try {
      const content = readFileSync(filePath, 'utf-8');
      const partName = this.extractPartName(filePath);
      
      if (!partName) return;

      // Update image paths in markdown content
      const updatedContent = this.updateImagePaths(content, partName);
      
      // Write to docs directory
      const outputPath = join(DOCS_DIR, `${partName}.md`);
      writeFileSync(outputPath, updatedContent, 'utf-8');
      
      console.log(`✅ Processed markdown: ${partName}.md`);
    } catch (error) {
      console.error(`❌ Error processing markdown ${filePath}:`, error);
    }
  }

  /**
   * Process an image file
   */
  processImageFile(filePath) {
    try {
      const partName = this.extractPartNameFromImagePath(filePath);
      if (!partName) return;

      const fileName = basename(filePath);
      const targetDir = join(STATIC_DIR, partName);
      
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
   * Extract part name from file path
   */
  extractPartName(filePath) {
    const match = filePath.match(/\/(part\d+[^\/]*|partmaybe[^\/]*)\//);
    return match ? match[1] : null;
  }

  /**
   * Extract part name from image path
   */
  extractPartNameFromImagePath(filePath) {
    const match = filePath.match(/\/(part\d+[^\/]*|partmaybe[^\/]*)\/images\//);
    return match ? match[1] : null;
  }

  /**
   * Update image paths in markdown content
   */
  updateImagePaths(content, partName) {
    // Replace image paths from images/filename to /partX/filename
    return content.replace(/!\[([^\]]*)\]\(images\/([^)]+)\)/g, (match, alt, filename) => {
      return `![${alt}](/${partName}/${filename})`;
    });
  }

  /**
   * Check if file is an image
   */
  isImageFile(filePath) {
    const ext = extname(filePath).toLowerCase();
    return ['.png', '.jpg', '.jpeg', '.svg', '.mmd'].includes(ext);
  }
}

// Singleton instance
export const fileWatcher = new FileWatcher();