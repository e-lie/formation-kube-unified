import { loadDocs } from '$lib/docs-static.js';

export async function load() {
  const docs = loadDocs();
  
  return {
    docs
  };
}