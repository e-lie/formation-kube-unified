---
title: "TP - Paramétrer monsterstack pour plusieurs environnements avec Kustomize"
description: "Guide TP - Paramétrer monsterstack pour plusieurs environnements avec Kustomize"
sidebar:
  order: 158
draft: false
---


## Gérer plusieurs environnements avec Kustomize

Kustomize est un outil de paramétrage et de mutation d'applications Kubernetes intégré directement dans `kubectl`. Il permet de gérer plusieurs variantes d'une même application (dev, staging, production) sans dupliquer les fichiers de configuration.

### Le problème à résoudre

Actuellement, notre application monsterstack utilise une ConfigMap pour sa configuration. Mais comment gérer différentes configurations pour différents environnements (dev, prod) sans dupliquer tous nos fichiers YAML ?

Kustomize résout ce problème en utilisant :
- Une **base** commune contenant les ressources partagées
- Des **overlays** (surcouches) pour chaque environnement qui modifient la base selon les besoins

### Architecture Kustomize

Nous allons créer une structure de dossiers comme suit :

```
k8s/
├── base/                    # Configuration de base (commune)
│   ├── kustomization.yaml
│   ├── frontend.yaml
│   ├── imagebackend.yaml
│   ├── redis.yaml
│   ├── redis-data-pvc.yaml
│   └── monsterstack-ingress.yaml
├── dev/                     # Overlay pour l'environnement dev
│   ├── kustomization.yaml
│   └── ingress-domain.yaml
└── prod/                    # Overlay pour l'environnement prod
    ├── kustomization.yaml
    ├── ingress-domain.yaml
    └── frontend-replicas.yaml
```

## Étape 1 : Créer la base

### Copier les fichiers existants

- Créez la structure de dossiers :
  ```bash
  mkdir -p k8s/base k8s/dev k8s/prod
  ```

- Copiez tous vos fichiers YAML actuels (du TP monsterstack configmap) dans `k8s/base/`, **sauf** le fichier `frontend-config.yaml` que nous allons générer automatiquement avec Kustomize.

### Créer le fichier kustomization.yaml de base

- Créez le fichier `k8s/base/kustomization.yaml` :

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- frontend.yaml
- imagebackend.yaml
- redis.yaml
- redis-data-pvc.yaml
- monsterstack-ingress.yaml

configMapGenerator:
- name: frontend-config
  literals:
  - CONTEXT=PROD
  - IMAGEBACKEND_DOMAIN=imagebackend
  - REDIS_DOMAIN=redis
```

**Explications** :
- `resources`: Liste des fichiers YAML à inclure
- `configMapGenerator`: Génère automatiquement une ConfigMap au lieu de la définir dans un fichier séparé
- Les `literals` sont les paires clé-valeur de la ConfigMap

### Tester la base

- Générez et visualisez le résultat sans déployer :
  ```bash
  kubectl kustomize k8s/base
  ```

Cette commande affiche tous les manifestes générés. Notez que la ConfigMap a un nom avec un hash ajouté automatiquement (ex: `frontend-config-abc123`). Cela permet de déclencher un rolling update quand la configuration change.

## Étape 2 : Créer l'overlay dev

### Créer le kustomization.yaml pour dev

- Créez le fichier `k8s/dev/kustomization.yaml` :

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../base

nameSuffix: -dev

configMapGenerator:
- name: frontend-config
  behavior: replace
  literals:
  - CONTEXT=DEV
  - IMAGEBACKEND_DOMAIN=imagebackend
  - REDIS_DOMAIN=redis

patches:
- target:
    kind: Ingress
    name: monsterstack
  path: ./ingress-domain.yaml
```

**Explications** :
- `resources: ../base`: Hérite de toutes les ressources de la base
- `nameSuffix: -dev`: Ajoute `-dev` à tous les noms de ressources
- `configMapGenerator` avec `behavior: replace`: Remplace la ConfigMap de base avec des valeurs pour dev
- `patches`: Modifie l'Ingress pour utiliser un domaine dev

### Créer le patch pour l'Ingress dev

- Créez le fichier `k8s/dev/ingress-domain.yaml` :

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: monsterstack
spec:
  tls:
  - hosts:
    - dev.elie.formation.dopl.uk
    secretName: monsterstack-tls-dev
  rules:
  - host: dev.elie.formation.dopl.uk
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 5000
```

**Comment ça marche ?**

Kustomize utilise une **strategic merge** : il fusionne intelligemment ce patch avec l'Ingress de base. Les champs spécifiés ici remplacent ceux de la base, les autres sont conservés.

### Tester l'overlay dev

- Visualisez le résultat pour dev :
  ```bash
  kubectl kustomize k8s/dev
  ```

Remarquez :
- Tous les noms ont le suffixe `-dev`
- La ConfigMap contient `CONTEXT=DEV`
- L'Ingress utilise `dev.elie.formation.dopl.uk`

## Étape 3 : Créer l'overlay prod

### Créer le kustomization.yaml pour prod

- Créez le fichier `k8s/prod/kustomization.yaml` :

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../base

nameSuffix: -prod

configMapGenerator:
- name: frontend-config
  behavior: replace
  literals:
  - CONTEXT=PROD
  - IMAGEBACKEND_DOMAIN=imagebackend
  - REDIS_DOMAIN=redis

patches:
- target:
    kind: Ingress
    name: monsterstack
  path: ./ingress-domain.yaml
- path: ./frontend-replicas.yaml
```

### Créer les patches pour prod

- Créez le fichier `k8s/prod/ingress-domain.yaml` :

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: monsterstack
spec:
  tls:
  - hosts:
    - prod.monsterstack.local
    secretName: monsterstack-tls-prod
  rules:
  - host: prod.monsterstack.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 5000
```

- Créez le fichier `k8s/prod/frontend-replicas.yaml` pour augmenter le nombre de réplicas en prod :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 7
```

Ce patch remplace simplement le nombre de replicas (3 dans la base → 7 en prod).

### Tester l'overlay prod

- Visualisez le résultat pour prod :

```bash
kubectl kustomize k8s/prod
```

Remarquez :
- Tous les noms ont le suffixe `-prod`
- La ConfigMap contient `CONTEXT=PROD`
- L'Ingress utilise `prod.monsterstack.local`
- Le frontend a 7 replicas au lieu de 3

## Étape 4 : Déployer avec Kustomize

### Déployer l'environnement dev

```bash
kubectl apply -k k8s/dev
```

L'option `-k` indique à kubectl d'utiliser Kustomize.

- Vérifiez les ressources créées :

```bash
kubectl get all -l app=monsterstack
kubectl get configmap | grep frontend-config
kubectl get ingress
```

Toutes les ressources devraient avoir le suffixe `-dev`.

### Déployer l'environnement prod (dans un autre namespace)

Pour isoler complètement les environnements, on peut les déployer dans des namespaces différents.

- Créez un namespace pour prod :
  ```bash
  kubectl create namespace prod
  ```

- Déployez dans le namespace prod :
  ```bash
  kubectl apply -k k8s/prod -n prod
  ```

- Vérifiez les ressources dans les deux namespaces :
  ```bash
  kubectl get all -n default -l app=monsterstack
  kubectl get all -n prod -l app=monsterstack
  ```

### Mettre à jour la configuration

Un des grands avantages de Kustomize : modifier facilement la configuration.

- Modifiez `k8s/dev/kustomization.yaml` pour changer `CONTEXT=DEV` en `CONTEXT=STAGING`

- Redéployez :
  ```bash
  kubectl apply -k k8s/dev
  ```

Le hash de la ConfigMap change automatiquement, ce qui déclenche un rolling update des pods frontend.

## Avantages de Kustomize

- **DRY (Don't Repeat Yourself)** : Pas de duplication de configuration
- **Versionning facile** : Tout est en YAML, versionnable dans Git
- **Natif dans kubectl** : Pas d'outil externe à installer
- **ConfigMap avec hash** : Les changements de config déclenchent automatiquement des rolling updates
- **Composabilité** : On peut créer des overlays d'overlays
- **Pas de templating** : Contrairement à Helm, Kustomize travaille avec des fichiers YAML valides

## Pour aller plus loin

### Intégration avec Skaffold

Skaffold supporte nativement Kustomize. Modifiez votre `skaffold.yaml` :

```yaml
apiVersion: skaffold/v2beta20
kind: Config
build:
  artifacts:
  - image: registry.example.com/frontend
deploy:
  kustomize:
    paths:
    - k8s/dev  # ou k8s/prod
```

### Autres fonctionnalités Kustomize

- **commonLabels** : Ajouter des labels à toutes les ressources
- **commonAnnotations** : Ajouter des annotations à toutes les ressources
- **images** : Modifier les tags d'images sans patcher
- **replicas** : Modifier le nombre de replicas directement dans kustomization.yaml
- **secretGenerator** : Générer des Secrets comme les ConfigMaps

## Ressources

- Documentation officielle : https://kubectl.docs.kubernetes.io/guides/introduction/kustomize/
- Kustomize GitHub : https://github.com/kubernetes-sigs/kustomize
- Article sur les patches : https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/