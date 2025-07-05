import { error } from '@sveltejs/kit';

// This will be populated by the server-side code
let postsCache = [];

export async function getPosts() {
	return postsCache;
}

export function getPost(slug) {
	const post = postsCache.find(p => p.slug === slug);
	if (!post) {
		throw error(404, 'Post not found');
	}
	return post;
}

// Server-side function to set posts cache
export function setPosts(posts) {
	postsCache = posts;
}