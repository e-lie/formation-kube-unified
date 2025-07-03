import { getPosts } from '$lib/posts.js';
import { error } from '@sveltejs/kit';

export async function load({ params }) {
  const posts = await getPosts();
  const post = posts.find(p => p.slug === params.slug);
  
  if (!post) throw error(404, 'Article non trouvé');
  
  return { post };
}