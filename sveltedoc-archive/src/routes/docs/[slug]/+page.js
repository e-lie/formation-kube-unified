export const prerender = true;

export async function entries() {
  const { getDocSlugs } = await import('$lib/docs-static.js');
  const slugs = getDocSlugs();
  
  return slugs.map(slug => ({
    slug
  }));
}