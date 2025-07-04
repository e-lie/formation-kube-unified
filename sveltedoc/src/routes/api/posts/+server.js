import { json } from '@sveltejs/kit';
import { loadPosts } from '$lib/posts.server.js';

export async function GET() {
	try {
		const posts = loadPosts();
		return json(posts);
	} catch (error) {
		console.error('Error loading posts:', error);
		return json([], { status: 500 });
	}
}