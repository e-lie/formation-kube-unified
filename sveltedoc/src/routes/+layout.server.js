import { loadDocs } from '$lib/docs.js';

export async function load() {
  const docs = loadDocs();
  
  return {
    docs
  };
}