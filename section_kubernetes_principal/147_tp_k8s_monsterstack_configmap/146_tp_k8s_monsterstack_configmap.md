---
draft: false
title: TP - Ajouter une Configuration dynamique ConfigMap
---

## Gérer la configuration avec des ConfigMaps

Actuellement notre application frontend utilise des variables d'environnement codées en dur directement dans le fichier de déploiement. Cette approche n'est pas idéale car elle mélange la configuration applicative avec la définition de l'infrastructure.

Nous allons maintenant externaliser cette configuration dans une **ConfigMap** Kubernetes, ce qui permettra de :
- Modifier la configuration sans toucher aux fichiers de déploiement
- Réutiliser la même configuration pour plusieurs déploiements
- Gérer différentes configurations pour différents environnements (dev, prod)

### État actuel

Dans le fichier `frontend.yaml`, nous avons actuellement trois variables d'environnement définies directement :

```yaml
env:
- name: CONTEXT
  value: PROD
- name: REDIS_DOMAIN
  value: redis
- name: IMAGEBACKEND_DOMAIN
  value: imagebackend
```

### Créer une ConfigMap

Une **ConfigMap** est un objet Kubernetes qui permet de stocker des données de configuration sous forme de paires clé-valeur.

- Créez un nouveau fichier `frontend-config.yaml` dans le dossier `k8s` avec le contenu suivant :

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-config
data:
  CONTEXT: "DEV"
  IMAGEBACKEND_DOMAIN: "imagebackend"
  REDIS_DOMAIN: "redis"
```

### Modifier le déploiement pour utiliser la ConfigMap

Maintenant que nous avons créé notre ConfigMap, nous devons modifier le déploiement frontend pour qu'il utilise les valeurs de cette ConfigMap au lieu des valeurs codées en dur.

- Modifiez la section `env` dans le fichier `frontend.yaml` comme suit :


```yaml
env:
- name: CONTEXT
  valueFrom:
    configMapKeyRef:
      name: frontend-config           # Le nom de la ConfigMap
      key: CONTEXT                    # La clé dans la ConfigMap
- name: REDIS_DOMAIN
  valueFrom:
    configMapKeyRef:
      name: frontend-config
      key: REDIS_DOMAIN
- name: IMAGEBACKEND_DOMAIN
  valueFrom:
    configMapKeyRef:
      name: frontend-config
      key: IMAGEBACKEND_DOMAIN
```


- `valueFrom`: Indique que la valeur provient d'une source externe (ici une ConfigMap)
- `configMapKeyRef`: Référence une clé spécifique dans une ConfigMap
- `name`: Le nom de la ConfigMap (doit correspondre au `metadata.name` de la ConfigMap)
- `key`: La clé dans la section `data` de la ConfigMap

### Déployer et tester

- Déployez la ConfigMap et le déploiement modifié :
```bash
kubectl apply -f k8s/frontend-config.yaml
kubectl apply -f k8s/frontend.yaml
```

- Vérifiez que la ConfigMap a été créée :
```bash
kubectl get configmap frontend-config
kubectl describe configmap frontend-config
```

- Vérifiez que les pods frontend ont bien redémarré avec la nouvelle configuration :
```bash
kubectl get pods -l partie=frontend
```

- Testez l'application pour vérifier qu'elle fonctionne toujours correctement.

### Avantages de cette approche

- **Séparation des "préoccupations"** : La configuration est séparée du code de déploiement donc on peut changer `CONTEXT` de `DEV` à `PROD` sans modifier le déploiement
- **Réutilisabilité** : La même ConfigMap peut être utilisée par plusieurs déploiements
- **Versionning** : Les ConfigMaps peuvent être versionnées dans Git
- **Gestion multi-environnements** : Créez différentes ConfigMaps pour dev, staging, prod

### Pour aller plus loin (facultatif)

Vous pouvez aussi injecter toute la ConfigMap comme variables d'environnement d'un coup avec `envFrom` :

```yaml
envFrom:
- configMapRef:
    name: frontend-config
```

Cette approche injecte automatiquement toutes les clés de la ConfigMap comme variables d'environnement.

Documentation officielle : https://kubernetes.io/docs/concepts/configuration/configmap/

## Correction du TP

La correction se trouve dans le dossier `146_tp_k8s_monsterstack_redis_pvc` du dépot de la formation (https://github.com/e-lie/formation-kube-unified)
