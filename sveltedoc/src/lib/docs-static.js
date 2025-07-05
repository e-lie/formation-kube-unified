import docsData from './docs-data.json';

export function loadDocs() {
  return docsData.docs;
}

export function getDoc(slug) {
  return docsData.docs.find(doc => doc.slug === slug);
}

export function getDocSlugs() {
  return docsData.slugs;
}