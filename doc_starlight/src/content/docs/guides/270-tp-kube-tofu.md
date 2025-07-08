---
title: "TP Kubernetes installé à la main - intégration multiprovider"
description: "Guide TP Kubernetes installé à la main - intégration multiprovider"
sidebar:
  order: 270
---


Ce TP déploie un cluster Kubernetes multi-nœuds sur Hetzner Cloud en utilisant OpenTofu (fork open-source de Terraform). L'infrastructure inclut un réseau VPN sécurisé avec WireGuard, un cluster etcd séparé, et la configuration automatique de Kubernetes avec Cilium comme CNI.

## Vue d'ensemble de l'architecture

### Schéma de l'infrastructure

![Architecture Kubernetes sur Hetzner Cloud](/270_tp_kube_tofu/images/architecture.png)

> **Note :** Le diagramme source est disponible dans le fichier `images/architecture.mmd` et peut être modifié puis recompilé avec la commande :  
> `mmdc -i images/architecture.mmd -o images/architecture.png -t dark -b transparent -s 2 -w 1200`

## Structure des modules

Le projet est organisé en modules réutilisables :

```sh
270_tp_kube_tofu/
├── 00_tp_kube_tofu.md          # Ce document
├── main.tf                      # Configuration principale
├── variables.tf                 # Variables globales
├── versions.tf                  # Versions des providers
├── provider/
│   └── hcloud/                  # Provider Hetzner Cloud
├── dns/
│   └── digitalocean/            # Configuration DNS
├── security/
│   ├── wireguard/              # VPN WireGuard
│   └── ufw/                    # Pare-feu UFW
├── service/
│   ├── etcd/                   # Cluster etcd
│   ├── kubernetes/             # Installation Kubernetes
│   └── swap/                   # Désactivation du swap
├── kubernetes_apps/            # Applications Kubernetes
│   └── nginx/                  # Déploiement nginx
└── file_output/                # Génération de fichiers
```

## Ordre de déploiement

Les modules sont déployés dans cet ordre précis pour respecter les dépendances :

1. **Provider (Hetzner Cloud)** : Création des serveurs virtuels
2. **Swap** : Désactivation du swap (requis pour Kubernetes)
3. **DNS** : Configuration des enregistrements DNS
4. **WireGuard** : Établissement du réseau VPN sécurisé
5. **Firewall (UFW)** : Configuration des règles de pare-feu
6. **etcd** : Déploiement du cluster etcd
7. **Kubernetes** : Installation et configuration du cluster
8. **File Output** : Génération des fichiers de configuration
9. **Kubernetes Apps** : Déploiement des applications (nginx)

## Configuration requise

### Prérequis

1. **OpenTofu** ou **Terraform** >= 1.0
2. **Compte Hetzner Cloud** avec un token API
3. **Compte DigitalOcean** avec un token API (pour DNS)
4. **Clés SSH** configurées
5. **Domaine** avec DNS géré par DigitalOcean

### Variables principales

```hcl
# Nombre de nœuds du cluster
node_count = 3

# Nombre de nœuds etcd (doit être impair)
etcd_node_count = 3

# Domaine et sous-domaine
domain = "example.com"
subdomain = "stagiaire1"

# Format des noms d'hôtes
hostname_format = "kube-stagiaire1%d"

# Réseaux
overlay_cidr = "10.96.0.0/16"  # Réseau pods Kubernetes

# Configuration Hetzner
hcloud_location = "nbg1"        # Nuremberg, Allemagne
hcloud_type = "cx11"           # Type d'instance (1 vCPU, 2GB RAM)
hcloud_image = "ubuntu-24.04"   # Image Ubuntu 24.04
```

## Déploiement

### 1. Configuration des variables

Créez un fichier `terraform.tfvars` :

```hcl
hcloud_token = "votre-token-hetzner"
hcloud_ssh_keys = ["nom-de-votre-cle-ssh"]
digitalocean_token = "votre-token-digitalocean"
domain = "votre-domaine.com"
subdomain = "votre-sous-domaine"
```

### 2. Initialisation et déploiement

```bash
# Initialiser OpenTofu/Terraform
tofu init

# Vérifier le plan
tofu plan

# Déployer l'infrastructure
tofu apply

# Récupérer la configuration kubectl
scp root@<IP-MASTER>:/root/.kube/config ~/.kube/config-hetzner
export KUBECONFIG=~/.kube/config-hetzner

# Vérifier le cluster
kubectl get nodes
kubectl get pods -A
```

### 3. Déploiement d'applications

Le module `kubernetes_apps/nginx` déploie automatiquement un exemple nginx :

```bash
# Vérifier le déploiement nginx
kubectl get deployment nginx-deployment
kubectl get service nginx-service
kubectl get pods -l app=nginx
```

## Composants déployés

### Infrastructure

- **3 serveurs** Ubuntu 24.04 sur Hetzner Cloud
- **Réseau privé** Hetzner pour communication interne
- **VPN WireGuard** pour sécuriser les communications
- **Pare-feu UFW** avec règles restrictives

### Kubernetes

- **Kubernetes** dernière version stable
- **etcd** cluster à 3 nœuds pour la haute disponibilité
- **Cilium** comme CNI (Container Network Interface)
- **CoreDNS** pour la résolution DNS interne
- **Metrics Server** pour les métriques

### Sécurité

- Communication chiffrée via WireGuard
- Pare-feu UFW restrictif
- API Kubernetes accessible uniquement via VPN
- etcd sécurisé avec TLS

## Module de déploiement nginx

Le module `kubernetes_apps/nginx` utilise le provider Kubernetes pour déployer :

- Un Deployment nginx avec 3 réplicas
- Un Service de type LoadBalancer
- Des labels et sélecteurs appropriés

Ce module démontre l'utilisation du provider Kubernetes pour gérer des ressources directement depuis OpenTofu/Terraform.

## Nettoyage

Pour détruire l'infrastructure :

```bash
# Détruire toutes les ressources
tofu destroy

# Nettoyer les fichiers générés
rm -f hosts kubeconfig.yaml
```

## Points d'attention

1. **Coûts** : Les serveurs Hetzner sont facturés à l'heure
2. **Sécurité** : Assurez-vous de sécuriser vos tokens API
3. **DNS** : La propagation DNS peut prendre quelques minutes
4. **Firewall** : Seuls les ports nécessaires sont ouverts
5. **Backups** : Pensez à sauvegarder les données etcd pour la production

## Dépannage

### Problèmes courants

1. **Connexion SSH impossible** : Vérifiez que votre clé SSH est bien configurée dans Hetzner
2. **DNS non résolu** : Attendez la propagation DNS (jusqu'à 5 minutes)
3. **Kubernetes non accessible** : Vérifiez que WireGuard est actif sur tous les nœuds
4. **Pods en erreur** : Vérifiez les logs avec `kubectl logs`

### Commandes utiles

```bash
# Vérifier l'état du cluster
kubectl cluster-info
kubectl get nodes -o wide

# Vérifier WireGuard
ssh root@<NODE-IP> "wg show"

# Vérifier etcd
ssh root@<NODE-IP> "etcdctl member list"

# Logs Kubernetes
kubectl logs -n kube-system <pod-name>
```