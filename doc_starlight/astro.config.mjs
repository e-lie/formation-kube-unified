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
					label: 'Cours principal',
					autogenerate: { directory: 'kubernetes-principal' },
				},
				{
					label: 'Aspects avancés',
					autogenerate: { directory: 'bonus' },
				},
				{
					label: 'GitOps & ArgoCD',
					autogenerate: { directory: 'gitops-argocd' },
				},
				{
					label: 'Clusters On-Premise',
					autogenerate: { directory: 'clusters-onpremise' },
				},
				// {
				// 	label: 'Statefulness & Storage',
				// 	autogenerate: { directory: 'statefulness-storage' },
				// },
				{
					label: 'Microservices & Istio',
					autogenerate: { directory: 'microservices-istio' },
				},
			],
			customCss: [
				// Chemin vers votre CSS personnalisé si nécessaire
				// './src/styles/custom.css',
			],
		}),
	],
});
