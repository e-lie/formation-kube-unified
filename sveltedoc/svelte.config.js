import { mdsvex } from 'mdsvex';
import adapter from '@sveltejs/adapter-static';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';
import { createHighlighter } from 'shiki';

const highlighter = await createHighlighter({
  themes: ['github-dark', 'github-light'],
  langs: ['javascript', 'typescript', 'svelte', 'bash', 'json', 'hcl', 'terraform', 'yaml', 'css', 'html']
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
          return highlighter.codeToHtml(code, {
            lang: lang || 'text',
            theme: 'github-dark'
          });
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