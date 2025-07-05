// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
	integrations: [
		starlight({
			title: 'Formation Terraform',
			description: 'Guide complet pour apprendre Terraform avec AWS',
			social: [
				{ icon: 'github', label: 'GitHub', href: 'https://github.com/votre-username/formation-terraform' }
			],
			sidebar: [
				{
					label: 'Formation Terraform',
					autogenerate: { directory: 'guides' },
				},
			],
			customCss: [
				// Chemin vers votre CSS personnalisé si nécessaire
				// './src/styles/custom.css',
			],
		}),
	],
});
