---
draft: false
title: TP - Ajouter une Configuration dynamique ConfigMap
# sidebar_position: 12
# sidebar_class_name: hidden
---


# Générer nos variables d'environnement frontend avec une configmap

En vous inspirant de la documentation officielle : https://kubernetes.io/docs/concepts/configuration/configmap/:

- Ajoutez un nouveau fichier configMap `frontend-config` avec 3 clés: `CONTEXT`, `REDIS_DOMAIN` et `IMAGEBACKEND_DOMAIN` avec les valeurs actuellement utilisées dans la section `env` de notre déloiement frontend.

- Modifiez cette section `env` pour récupérer les valeurs de la configMap avec le paramètre `valueFrom` comme dans l'exemple.