// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
	site: 'https://support-terraform.eliegavoty.fr',
	// base: '/', // Pas de base path avec un domaine custom
	integrations: [
		starlight({
			title: 'Formation Terraform',
			description: 'Guide complet pour apprendre Terraform avec AWS',
			social: [
				{ icon: 'github', label: 'GitHub', href: 'https://github.com/e-lie/formation-terraform-unified' }
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
