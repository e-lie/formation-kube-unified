export async function getPosts() {
  const modules = import.meta.glob('/src/lib/posts/*.md');
  const posts = [];
  
  for (const path in modules) {
    const mod = await modules[path]();
    const slug = path.split('/').pop().replace('.md', '');
    
    posts.push({
      slug,
      metadata: mod.metadata || {},
      content: mod.default
    });
  }
  
  // Sort by part number
  return posts.sort((a, b) => {
    const numA = parseInt(a.slug.match(/\d+/)?.[0] || '0');
    const numB = parseInt(b.slug.match(/\d+/)?.[0] || '0');
    return numA - numB;
  });
}