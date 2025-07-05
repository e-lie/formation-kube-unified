
- un site de documentation statique utilisant sveltekit
- les pages de blog sont générées à partir de fichiers markdown pointant également vers des images
- utilise l'adapter static sveltekit pour avoir du SSR avec hot reload en dev (npm run dev)
- les fichiers markdown et images doivent également être crawlées/recherchés depuis la racine du projet et copiés dynamiquement au bon endroit (avec les images) dans le dossier du projet sveltekit dont il est question ici (sveltedoc). cela doit être déclenché automatiquement au lancement de npm run dev ou build ou avec une tache dédiée sync
- utilise vite, tailwind mais pas postcss
- utilise le theme : https://www.sveltethemes.com/theme/sveltejs-kit/ (est-ce un theme ou une référence à sveltekit ?)
- utilise le layout de documentation du site officiel comme sur cette page : https://svelte.dev/docs/svelte/overview
- configure la coloration syntaxique pour les bloc de code markdown
