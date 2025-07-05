import { readFileSync, readdirSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { marked } from 'marked';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const POSTS_DIR = join(__dirname, 'posts');

// Function to parse frontmatter
function parseFrontmatter(content) {
	const match = content.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
	if (!match) {
		return { metadata: {}, content };
	}
	
	const [, frontmatter, body] = match;
	const metadata = {};
	
	frontmatter.split('\n').forEach(line => {
		const colonIndex = line.indexOf(':');
		if (colonIndex > 0) {
			const key = line.slice(0, colonIndex).trim();
			const value = line.slice(colonIndex + 1).trim();
			metadata[key] = isNaN(value) ? value : Number(value);
		}
	});
	
	return { metadata, content: body };
}

// Function to load posts dynamically
export function loadPosts() {
	if (!existsSync(POSTS_DIR)) {
		return [];
	}
	
	const files = readdirSync(POSTS_DIR).filter(file => file.endsWith('.md'));
	
	return files.map(file => {
		const filePath = join(POSTS_DIR, file);
		const content = readFileSync(filePath, 'utf-8');
		const { metadata, content: body } = parseFrontmatter(content);
		const slug = file.replace('.md', '');
		
		return {
			slug,
			title: metadata.title || slug,
			weight: metadata.weight || 999,
			metadata,
			content: body,
			html: marked(body)
		};
	}).sort((a, b) => a.weight - b.weight);
}