#!/usr/bin/env node

import { readFileSync, readdirSync, existsSync, writeFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { marked } from 'marked';
import { createHighlighter } from 'shiki';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const DOCS_DIR = join(__dirname, 'src/docs');

// Initialize highlighter
const highlighter = await createHighlighter({
  themes: ['github-dark', 'github-light'],
  langs: [
    'javascript', 'typescript', 'svelte', 'bash', 'shell', 'sh',
    'json', 'hcl', 'terraform', 'yaml', 'css', 'html',
    'coffeescript', 'coffee', 'text', 'plaintext'
  ]
});

// Custom renderer to handle code blocks with Shiki
const renderer = new marked.Renderer();
renderer.code = function(code, infostring, escaped) {
  // Handle case where code is an object (from marked tokens)
  let codeText, language;
  
  if (typeof code === 'object' && code.text) {
    codeText = code.text;
    language = code.lang || '';
  } else if (typeof code === 'string') {
    codeText = code;
    language = (infostring || '').match(/\S*/)?.[0] || '';
  } else {
    console.warn('Unexpected code format:', typeof code, code);
    return `<pre><code>Invalid code block</code></pre>`;
  }
  
  // Map common aliases to supported languages
  const langMap = {
    'coffee': 'coffeescript',
    'bash': 'bash', 
    'shell': 'bash',
    'sh': 'bash',
    'hcl': 'hcl',
    'terraform': 'hcl',
    'tf': 'hcl'
  };
  
  const resolvedLang = langMap[language] || language || 'text';
  
  try {
    const highlighted = highlighter.codeToHtml(codeText, {
      lang: resolvedLang,
      theme: 'github-dark',
      transformers: [
        {
          code(node) {
            node.properties['data-language'] = resolvedLang;
          }
        }
      ]
    });
    return highlighted;
  } catch (error) {
    console.warn(`Failed to highlight ${language || 'unknown'} code:`, error.message);
    // Fallback to basic highlighting
    try {
      return highlighter.codeToHtml(codeText, {
        lang: 'text',
        theme: 'github-dark'
      });
    } catch (fallbackError) {
      // Final fallback
      const escapedCode = codeText
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
      return `<pre><code class="language-${language || 'text'}">${escapedCode}</code></pre>`;
    }
  }
};

// Configure marked with custom renderer
marked.setOptions({
  renderer: renderer
});

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