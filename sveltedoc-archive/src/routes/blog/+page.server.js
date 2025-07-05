import { loadPosts } from '$lib/posts.server.js';

export async function load() {
  const posts = loadPosts();
  return { posts };
}