---
title: "Cours - Service mesh et Istio"
description: "Guide Cours - Service mesh et Istio"
sidebar:
  order: 320
---


## Le mesh networking et les *service meshes*

Un **service mesh** est un type d'outil réseau pour connecter un ensemble de pods, généralement les parties d'une application microservices de façon encore plus intégrée que ne le permet Kubernetes, mais également plus sécurisé et contrôlable.

En effet opérer une application composée de nombreux services fortement couplés discutant sur le réseau implique des besoins particuliers en terme de routage des requêtes, sécurité et monitoring qui nécessite l'installation d'outils fortement dynamique autour des nos conteneurs.

Un exemple de service mesh est `https://istio.io` qui, en ajoutant dynamiquement un conteneur "sidecar" à chacun des pods à supervisés, ajoute à notre application microservice un ensemble de fonctionnalités d'intégration très puissant.

Un autre service mesh populaire et "plus simple" qu'Istio, Linkerd : https://linkerd.io/

Cilium, le plugin réseau CNI peut aussi opérer comme un service mesh

- https://www.youtube.com/watch?v=16fgzklcF7Y

## Istio

Istio est un **service mesh** open source qui peut se superposer de manière transparente aux applications distribuées existantes.

Il offrent un moyen uniforme et efficace de sécuriser, connecter et surveiller les services. Il ajoute au cluster, avec peu ou pas de modifications du code des services.

- des fonctionnalités plus flexibles et puissantes que le coeur de Kubernetes pour le LoadBalancing entre les services. Notamment un loadbalancing L7 (la couche réseau application) du trafic HTTP, gRPC, WebSocket et TCP

- une authentification entre les services

- une autorisation fine des communications basée sur cette authentification

- une communication chiffrée avec TLS mutuel

- la surveillance du trafic dans le mesh en temps réel

- Un contrôle granulaire du trafic avec des règles de routage riches, des retry automatiques pour les requêtes, des failovers en cas de panne d'un service et un mechanisme de **fault injection**.

- Une couche de politique de sécurité modulaire. l'API de configuration permet d'exprimer des contrôles d'accès, des ratelimits et des quotas pour le traffic

- Istio expose aussi des métriques, des journaux et des traces (chaine d'appels reseau) pour tout le trafic au sein d'un cluster, y compris concernant le traffic entrant et sortant (ingress et egress) du cluster.

- Istio est conçu pour être extensible et gère une grande variété de besoins de déploiement.

### Architecture de Istio - Mode Sidecar (Classique)

![Architecture Istio Sidecar](/section_microservices_istio/320_cours_service_mesh_istio/images/istio-sidecar-architecture.svg)

**Composants principaux :**

- **Istiod** (Control Plane) : Contrôleur centralisé qui gère la configuration, la découverte de services, et la distribution des certificats
- **Envoy Proxies** (Data Plane) : Proxies sidecar injectés dans chaque pod pour intercepter et gérer le trafic
- **Ingress/Egress Gateways** : Points d'entrée et de sortie du mesh pour le trafic externe

**Fonctionnement :**
1. **Istiod** configure les proxies via l'API xDS (configuration dynamique)
2. Chaque **sidecar Envoy** intercepte tout le trafic entrant/sortant de son pod
3. Communication sécurisée avec **mTLS automatique** entre les services
4. **Télémétrie** centralisée (métriques, logs, traces) remontée vers Istiod

### Istio par l'exemple et autres resources

- [https://istiobyexample.dev/](https://web.archive.org/web/20250128033824/https://istiobyexample.dev/)

- https://www.istioworkshop.io/09-traffic-management/06-circuit-breaker/

### CRDs de Istio

Istio utilise plusieurs Custom Resource Definitions (CRDs) pour étendre les fonctionnalités de Kubernetes et permettre la configuration de ses différents composants:

- **VirtualService** : Le CRD `VirtualService` permet de définir les règles de trafic pour contrôler le routage des requêtes HTTP et TCP vers différentes destinations dans le maillage Istio. Il est utilisé pour configurer des fonctionnalités telles que le routage basé sur des en-têtes, des poids du trafic, des redirections et des destinations de service.

- **DestinationRule** : Le CRD `DestinationRule` est utilisé pour définir les règles de trafic spécifiques à une destination, telles que la configuration des politiques de répartition de charge, des réplicas et des stratégies de rééquilibrage de charge.

- **Gateway** : Le CRD `Gateway` est utilisé pour configurer les points d'entrée de trafic externes dans le maillage Istio. Il permet de définir des règles pour l'exposition de services Istio à l'extérieur du maillage, comme l'exposition de services HTTP, HTTPS et TCP.

- **ServiceEntry** : Le CRD `ServiceEntry` est utilisé pour déclarer des services externes (non-Istio) au sein du maillage Istio. Il permet à Istio de gérer la communication avec des services situés en dehors du maillage et d'appliquer des politiques de sécurité, de trafic et de résilience à ces services.

- **Sidecar** : Le CRD `Sidecar` est utilisé pour configurer les sidecars Envoy dans les pods de votre application. Il permet de définir des options de configuration spécifiques pour chaque sidecar, telles que les politiques de trafic, les filtres réseau et les règles de sécurité.

- **AuthorizationPolicy** : Le CRD `AuthorizationPolicy` est utilisé pour définir des politiques de contrôle d'accès basées sur les rôles et les permissions pour les services dans le maillage Istio. Il permet de spécifier des règles d'autorisation pour limiter l'accès aux services en fonction des identités et des attributs de requête.

### Istio et API Gateway

Istio soutient la standardisation via la norme API Gateway de Kubernetes. Il est donc possible d'utiliser les CRDs de l'API Gateway pour configurer le routage du trafic et les points d'entrée du mesh plutôt que les CRDs de Istio.

**Correspondance entre les CRDs Istio et Gateway API :**

| **Istio CRD** | **Gateway API CRD** | **Utilisation** |
|---------------|---------------------|-----------------|
| `Gateway` | `Gateway` | Points d'entrée du mesh |
| `VirtualService` | `HTTPRoute`, `TLSRoute`, `TCPRoute` | Règles de routage L7/L4 |
| `DestinationRule` | `BackendPolicy` (expérimental) | Politiques de trafic (load balancing, circuit breaker) |
| `ServiceEntry` | Pas d'équivalent direct | Services externes au cluster |
| `AuthorizationPolicy` | `SecurityPolicy` (en développement) | Politiques d'autorisation |

> **Note** : L'API Gateway ne supporte pas encore tous les cas d'usage d'Istio. Pour une standardisation à long terme, elle peut être intéressante, mais la documentation reste moins fournie. Les CRDs de l'API Gateway doivent être installés indépendamment d'Istio.

### Architecture Ambient Mesh (Nouvelle approche)

![Architecture Istio Ambient](/section_microservices_istio/320_cours_service_mesh_istio/images/istio-ambient-architecture.svg)

L'architecture classique de Istio avec des proxies sidecar pour chaque pod peut être lourde à mettre en œuvre et consommatrice en ressources. Istio développe une nouvelle architecture appelée **Ambient Mesh** qui simplifie le déploiement.

**Composants de l'Ambient Mesh :**

- **ztunnel** : Proxy L4 déployé sur chaque nœud (DaemonSet) qui gère :
  - La sécurité mTLS entre les nœuds
  - L'identité des workloads
  - La redirection du trafic via eBPF/CNI
  - La télémétrie de niveau 4

- **Waypoint Proxies** (optionnels) : Proxies L7 déployés uniquement quand nécessaire pour :
  - Les politiques avancées (autorisation fine, rate limiting)
  - Le routage complexe et circuit breakers
  - Les fonctionnalités L7 (HTTP headers, retries)

**Avantages de l'Ambient Mesh :**

1. **Simplicité** : Pas de modification des pods applicatifs (pas de sidecar)
2. **Performance** : Moins de ressources consommées, communication directe L4
3. **Adoption progressive** : Activation du mesh par namespace sans redéploiement
4. **Flexibilité** : L7 uniquement quand nécessaire via les Waypoint Proxies

**Mode de fonctionnement :**

1. Le trafic entre pods est automatiquement intercepté par **ztunnel** via CNI
2. **ztunnel** assure la sécurité mTLS et l'observabilité L4
3. Si des politiques L7 sont requises, le trafic passe par un **Waypoint Proxy**
4. La configuration reste centralisée via **Istiod**


<!-- ## Essayer Istio

- Cloner l'application d'exemple bookinfo :

```sh
cd ~/Desktop
git clone https://github.com/istio/istio.git
cp -R istio/sample/bookinfo .
```

- Suivez le tutoriel officiel à l'adresse : https://istio.io/latest/docs/setup/getting-started/
 -->

<!-- 
## Principes et architecture


### Pour aller plus loin


## Déployer Istio

#### 1. Déployer les Custom Resource Definitions avec le chart Istio base:

```sh
helm repo add istio https://istio-release.storage.googleapis.com/charts

helm repo update

kubectl create namespace istio-system

helm install istio-base istio/base -n istio-system --set defaultRevision=default
```

C'est une bonne pratique générale de ne pas déployer les CRDs avec le chart principal de l'application/opérateur que l'on veut installer. En effet :

- Désinstaller une release d'un chart est une opération assez commune
- Désinstaller une release comprenant des CRDs va désinstaller ces CRDs
- Désinstaller les CRDs implique la suppression définitive des resources associées ce qui implique une perte de données potentiellement grave

On pourrait vouloir utiliser plusieurs releases du même chart sans toucher aux CRDs et la 

#### 2. Installer le control plane Istio via une application ArgoCD

```sh
helm install istiod istio/istiod -n istio-system --set "profile=demo" --wait
```

## Déployer l'application d'exemple bookinfo

- Cloner l'application: `git clone https://github.com/Uptime-Formation/istio_bookinfo_TPs.git`

- Créer un namespace pour l'application : `kubectl create namespace bookinfo`.

- Activer l'injection de sidecar (le mode normal de Istio) pour le namespace: `kubectl label namespace bookinfo istio-injection=enabled`

Le controller Istiod surveille les namespaces étiquetés de la sorte.

Déployons l'application avec ArgoCD
 -->

