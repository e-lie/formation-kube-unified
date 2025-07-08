# Images du TP Kubernetes

Ce dossier contient les diagrammes d'architecture pour le TP Kubernetes.

## Fichiers disponibles

- `architecture.mmd` - Source Mermaid du diagramme d'architecture
- `architecture.png` - Diagramme compilé (thème sombre, fond transparent)
- `architecture-light.png` - Diagramme compilé (thème clair, fond blanc)

## Modifier le diagramme

Pour modifier le diagramme d'architecture :

1. Éditez le fichier `architecture.mmd`
2. Recompilez avec Mermaid CLI :

```bash
# Thème sombre (recommandé) - Haute résolution
mmdc -i architecture.mmd -o architecture.png -t dark -b transparent -s 2 -w 1200

# Thème clair - Haute résolution
mmdc -i architecture.mmd -o architecture-light.png -t neutral -b white -s 2 -w 1200
```

### Options de résolution

- `-s 2` : Scale factor 2x (double la résolution)
- `-w 1200` : Largeur de 1200px (au lieu de 800px par défaut)
- Ces options garantissent une qualité optimale pour l'impression et l'affichage haute résolution

## Prérequis

Installation de Mermaid CLI :

```bash
npm install -g @mermaid-js/mermaid-cli
```

Ou avec les gestionnaires de paquets système :

```bash
# Ubuntu/Debian
apt install mermaid-cli

# Arch Linux
pacman -S mermaid-cli
```