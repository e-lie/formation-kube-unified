import { loadPosts } from '$lib/posts.server.js';
import { error } from '@sveltejs/kit';

export async function load({ params }) {
  const posts = loadPosts();
  const post = posts.find(p => p.slug === params.slug);
  
  if (!post) throw error(404, 'Article non trouvé');
  
  return { post };
}

export function entries() {
  const posts = loadPosts();
  return posts.map(post => ({ slug: post.slug }));
}