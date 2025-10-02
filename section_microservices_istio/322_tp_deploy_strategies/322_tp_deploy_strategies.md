---
title: TP optionnel - Stratégies de déploiement
---

### Déployer notre application d'exemple (goprom) et la connecter à prometheus

<!-- Prometheus deploie les services suivants... -->

Nous allons installer une petite application d'exemple en go.

- Téléchargez le code de l'application et de son déploiement depuis github: `git clone https://github.com/e-lie/k8s-deployment-strategies`

Nous allons d'abord construire l'image docker de l'application à partir des sources et la déployer dans le cluster.

- Allez dans le dossier `goprom_app` et "construisez" l'image docker de l'application avec le tag `<votrelogindockerhub>/goprom`.

<details><summary>Réponse</summary>

```bash
cd goprom_app
docker build -t tecpi/goprom .
```

</details>

- Allez dans le dossier de la première stratégie `recreate` et ouvrez le fichier `app-v1.yml`. Notez que `image:` est à `tecpi/goprom` et qu'un paramètre `imagePullPolicy` est défini à `Never`. Changez ces paramètres si nécessaire (oui en général).


- Appliquez ce déploiement kubernetes:

<details><summary>Réponse</summary>

```bash
cd '../k8s-strategies/1 - recreate'
kubectl apply -f app-v1.yml
```

</details>

### Observons notre application et son déploiement kubernetes

- Explorez le fichier de code go de l'application `main.go` ainsi que le fichier de déploiement `app-v1.yml`. Quelles sont les routes http exposées par l'application ?

<details><summary>Réponse</summary>

- L'application est accessible sur le port `8080` du conteneur et la route `/`.
- L'application expose en plus deux routes de diagnostic (`probe`) kubernetes sur le port `8086` sur `/live` pour la `liveness` et `/ready` pour la `readiness` (cf https://kubernetes.io/docs/)
- Enfin, `goprom` expose une route spécialement pour le monitoring Prometheus sur le port `9101` et la route `/metrics`

</details>

- Utilisez le service `NodePort` pour accéder au service `goprom` dans votre navigateur.

- Utilisez le service `NodePort` pour accéder au service `goprom-metrics` dans votre navigateur. Quelles informations récupère-t-on sur cette route ?

- Pour tester le service `prometheus-server` nous avons besoin de le mettre en mode NodePort (et non ClusterIP par défaut). Modifiez le service dans Lens pour changer son type.
- Exposez le service avec un NodePort (n'oubliez pas de préciser le namespace monitoring).
- Vérifiez que prometheus récupère bien les métriques de l'application avec la requête PromQL : `sum(rate(http_requests_total{app="goprom"}[5m])) by (version)`.

- Quelle est la section des fichiers de déploiement qui indique à prometheus ou récupérer les métriques ?

<details><summary>Réponse</summary>

```yaml
apiVersion: apps/v1
kind: Deployment
---
spec:
---
template:
  metadata:
---
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "9101"
```

</details>


Créer une dashboard avec un Graphe. Utilisez la requête prometheus (champ query suivante):

```
sum(rate(http_requests_total{app="goprom"}[5m])) by (version)
```

Pour avoir un meilleur aperçu de la version de l'application accédée au fur et à mesure du déploiement, ajoutez `{{version}}` dans le champ `legend`.

### Observer un basculement de version

Ce TP est basé sur l'article suivant: https://blog.container-solutions.com/kubernetes-deployment-strategies

Maintenant que l'environnement a été configuré :

- Lisez l'article.
- Vous pouvez testez les différentes stratégies de déploiement en lisant leur `README.md`.
- En résumé, pour les plus simple, on peut:
  - appliquer le fichier `app-v1.yml` pour une stratégie.
  - lançer la commande suivante pour effectuer des requêtes régulières sur l'application: `service=$(minikube service goprom --url) ; while sleep 0.1; do curl "$service"; done`
  - Dans un second terminal (pendant que les requêtes tournent) appliquer le fichier `app-v2.yml` correspondant.
  - Observez la réponse aux requêtes dans le terminal ou avec un graphique adapté dans `graphana` (Il faut configurer correctement le graphique pour observer de façon lisible la transition entre v1 et v2). Un aperçu en image des histogrammes du nombre de requêtes en fonction des versions 1 et 2 est disponible dans chaque dossier de stratégie.
  - supprimez le déploiement+service avec `delete -f` ou dans Lens.

Par exemple pour la stratégie **recreate** le graphique donne: ![](/img/prometheus/grafana-recreate.png)

### Argo Rollout : un exemple d'opérateur de rollout (controller)

![](/img/kubernetes/argo-rollout-architecture.webp)

#### **Stratégies de déploiement avancées**

##### **Canary Deployment**
Avec la stratégie canary, le rollout peut scale un ReplicaSet avec la nouvelle version pour recevoir un pourcentage spécifié de trafic, attendre un temps spécifié, puis revenir au pourcentage 0, et enfin déployer tout le trafic une fois que l'utilisateur est satisfait.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp
spec:
  replicas: 5
  strategy:
    canary:
      steps:
      - setWeight: 20    # 20% du trafic vers canary
      - pause: {duration: 1m}
      - setWeight: 40
      - pause: {duration: 1m}
      - setWeight: 60
      - pause: {duration: 1m}
      - setWeight: 80
      - pause: {duration: 1m}
```

##### **Blue-Green Deployment**
Avec la stratégie BlueGreen, Argo Rollouts permet aux utilisateurs de spécifier un service preview et un service active. Le Rollout configurera le service preview pour envoyer du trafic vers la nouvelle version tandis que le service active continue à recevoir le trafic de production.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp
spec:
  replicas: 3
  strategy:
    blueGreen:
      activeService: myapp-active
      previewService: myapp-preview
      autoPromotionEnabled: false
      scaleDownDelaySeconds: 30
```

#### **Analyse automatique (Canary Analysis)**

Intégration avec des fournisseurs de métriques pour automatiser les décisions :

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp
spec:
  strategy:
    canary:
      analysis:
        templates:
        - templateName: success-rate
        startingStep: 2
        args:
        - name: service-name
          value: myapp
```

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  args:
  - name: service-name
  metrics:
  - name: success-rate
    interval: 5m
    successCondition: result[0] >= 0.95
    failureLimit: 3
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          sum(rate(
            http_requests_total{service="{{args.service-name}}",status=~"2.."}[5m]
          )) / 
          sum(rate(
            http_requests_total{service="{{args.service-name}}"}[5m]
          ))
```

#### **Intégrations avec Traffic Management**

Argo Rollouts s'intègre (optionnellement) avec les ingress controllers et les service meshes, exploitant leurs capacités de traffic shaping pour progressivement déplacer le trafic vers la nouvelle version pendant une mise à jour.

**Providers supportés :**
- **Service Meshes** : Istio, Linkerd, AWS App Mesh, SMI
- **Ingress Controllers** : NGINX, ALB (AWS), Traefik, Ambassador, Apache APISIX
- **Gateway API** : Support natif pour la nouvelle Gateway API Kubernetes

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp
spec:
  strategy:
    canary:
      trafficRouting:
        istio:
          virtualService:
            name: myapp-vsvc
            routes:
            - primary
      steps:
      - setWeight: 10
      - pause: {duration: 5m}
```

#### **Rollback automatique**

En cas de problème détecté par l'analyse :

```yaml
spec:
  strategy:
    canary:
      analysis:
        templates:
        - templateName: error-rate
        startingStep: 1
      abortScaleDownDelaySeconds: 30  # Garde les pods pour debug
```

#### Alternatives

- Flagger
- ?



### Facultatif : Installer Istio pour des scénarios plus avancés

Pour des scénarios plus avancés de déploiement, on a besoin d'utiliser soit un _service mesh_ comme Istio (soit un plugin de rollout comme Argo Rollouts mais pas ce que nous proposons ici).

<!-- TODO trouver comment exporter les bonnes dashboard grafana pour les réimporter plus + comprendre un peu mieux promQL -->

1. Sur k3s, supprimer la release Helm du Ingress Controller Traefik (ou le ingress Nginx) pour le remplacer par l'ingress Istio.
2. Installer Istio, créer du trafic vers l'ingress de l'exemple et afficher le graphe de résultat dans le dashboard Istio : https://istio.io/latest/docs/setup/getting-started/
3. Utiliser ces deux ressources pour appliquer une stratégie de déploiement de type A/B testing poussée :
   - https://istio.io/latest/docs/tasks/traffic-management/request-routing/
   - https://github.com/ContainerSolutions/k8s-deployment-strategies/tree/master/ab-testing

