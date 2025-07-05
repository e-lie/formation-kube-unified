import { mdsvex } from 'mdsvex';
import adapter from '@sveltejs/adapter-static';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';
import { createHighlighter } from 'shiki';

const highlighter = await createHighlighter({
  themes: ['github-dark', 'github-light'],
  langs: [
    'javascript', 'typescript', 'svelte', 'bash', 'shell', 'sh',
    'json', 'hcl', 'terraform', 'yaml', 'css', 'html',
    'coffeescript', 'coffee', 'text', 'plaintext'
  ]
});

/** @type {import('@sveltejs/kit').Config} */
const config = {
  extensions: ['.svelte', '.md', '.svx'],
  
  preprocess: [
    vitePreprocess(),
    mdsvex({
      extensions: ['.md', '.svx'],
      highlight: {
        highlighter: (code, lang) => {
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
          
          const resolvedLang = langMap[lang] || lang || 'text';
          
          try {
            return highlighter.codeToHtml(code, {
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
          } catch (error) {
            // Fallback to plain text if language is not supported
            return highlighter.codeToHtml(code, {
              lang: 'text',
              theme: 'github-dark'
            });
          }
        }
      },
      remarkPlugins: [],
      rehypePlugins: []
    })
  ],
  
  kit: {
    adapter: adapter({
      pages: 'build',
      assets: 'build',
      fallback: null,
      precompress: false,
      strict: false
    })
  }
};

export default config;