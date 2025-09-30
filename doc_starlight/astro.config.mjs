// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
	site: 'https://support-kube.eliegavoty.fr',
	// base: '/', // Pas de base path avec un domaine custom
	integrations: [
		starlight({
			title: 'Formation Kubernetes',
			description: 'Guide complet pour apprendre Kubernetes, Helm et Istio',
			social: [
				{ icon: 'github', label: 'GitHub', href: 'https://github.com/e-lie/formation-kubernetes-unified' }
			],
			sidebar: [
				{
					label: 'Kubernetes Principal',
					autogenerate: { directory: 'kubernetes-principal' },
				},
				{
					label: 'Helm',
					autogenerate: { directory: 'helm' },
				},
				{
					label: 'Istio & Service Mesh',
					autogenerate: { directory: 'istio' },
				},
			],
			customCss: [
				// Chemin vers votre CSS personnalisé si nécessaire
				// './src/styles/custom.css',
			],
		}),
	],
});
