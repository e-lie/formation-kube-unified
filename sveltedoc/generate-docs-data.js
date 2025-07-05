#!/usr/bin/env node

import { readFileSync, readdirSync, existsSync, writeFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { marked } from 'marked';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const DOCS_DIR = join(__dirname, 'src/docs');

// Function to parse frontmatter
function parseFrontmatter(content) {
  const match = content.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!match) {
    return { metadata: {}, content };
  }
  
  const [, frontmatter, body] = match;
  const metadata = {};
  
  frontmatter.split('\n').forEach(line => {
    const colonIndex = line.indexOf(':');
    if (colonIndex > 0) {
      const key = line.slice(0, colonIndex).trim();
      const value = line.slice(colonIndex + 1).trim();
      metadata[key] = isNaN(value) ? value : Number(value);
    }
  });
  
  return { metadata, content: body };
}

// Function to load docs dynamically
function loadDocs() {
  if (!existsSync(DOCS_DIR)) {
    return [];
  }
  
  const files = readdirSync(DOCS_DIR).filter(file => file.endsWith('.md'));
  
  return files.map(file => {
    const filePath = join(DOCS_DIR, file);
    const content = readFileSync(filePath, 'utf-8');
    const { metadata, content: body } = parseFrontmatter(content);
    const slug = file.replace('.md', '');
    
    // Extract part number for sorting
    const partMatch = slug.match(/part(\d+)/);
    const partNumber = partMatch ? parseInt(partMatch[1]) : 999;
    
    return {
      slug,
      title: metadata.title || slug,
      weight: metadata.weight || partNumber,
      metadata,
      content: body,
      html: marked(body)
    };
  }).sort((a, b) => a.weight - b.weight);
}

console.log('📚 Generating docs data...');

const docs = loadDocs();
const docsData = {
  docs,
  slugs: docs.map(doc => doc.slug),
  lastGenerated: new Date().toISOString()
};

// Write to a JSON file
writeFileSync(
  join(__dirname, 'src/lib/docs-data.json'),
  JSON.stringify(docsData, null, 2)
);

console.log(`✅ Generated data for ${docs.length} documents`);
docs.forEach(doc => {
  console.log(`  - ${doc.slug}: ${doc.title}`);
});