import { getDoc, loadDocs } from '$lib/docs.js';
import { error } from '@sveltejs/kit';

export async function load({ params }) {
  const doc = getDoc(params.slug);
  
  if (!doc) {
    throw error(404, 'Document not found');
  }

  // Get navigation (prev/next)
  const allDocs = loadDocs();
  const currentIndex = allDocs.findIndex(d => d.slug === params.slug);
  
  const prevDoc = currentIndex > 0 ? allDocs[currentIndex - 1] : null;
  const nextDoc = currentIndex < allDocs.length - 1 ? allDocs[currentIndex + 1] : null;

  return {
    doc,
    prevDoc,
    nextDoc
  };
}