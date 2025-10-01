---
title: Cours - L'opérateur CertManager
draft: true
---

# Cours : cert-manager pour Kubernetes

## Introduction

cert-manager est un contrôleur Kubernetes qui automatise la gestion et le renouvellement des certificats TLS. Il transforme la gestion des certificats en ressources Kubernetes déclaratives, éliminant ainsi les processus manuels fastidieux.

## Architecture générale

cert-manager fonctionne selon un modèle de réconciliation continue typique de Kubernetes. Il surveille les ressources qu'il gère et s'assure que l'état réel correspond à l'état désiré.

<!-- ### Composants principaux

**1. cert-manager Controller**
Le contrôleur principal qui orchestre la création et le renouvellement des certificats.

**2. Webhook**
Valide et mute les ressources cert-manager lors de leur création/modification.

**3. CA Injector**
Injecte automatiquement les CA bundles dans les ressources qui en ont besoin (webhooks, API services). -->

## Les Custom Resource Definitions (CRDs)

cert-manager introduit plusieurs CRDs qui constituent son API. Voici les principales ressources :

### 1. Issuer et ClusterIssuer

Les Issuers représentent les autorités de certification qui peuvent émettre des certificats.

**Issuer** : Limité à un namespace spécifique
```yaml
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: letsencrypt-staging
  namespace: default
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-staging-key
    solvers:
    - http01:
        ingress:
          class: nginx
```

**ClusterIssuer** : Disponible dans tous les namespaces
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
    - http01:
        ingress:
          class: nginx
```

**Types d'Issuers disponibles (voir section plus loin):**
- **ACME** (Let's Encrypt) : Certificats gratuits avec validation automatique
- **CA** : Utilise une paire de clés CA existante
- **Vault** : HashiCorp Vault PKI
- **Venafi** : Solutions enterprise
- **SelfSigned** : Auto-signé (pour développement/test)
- **External** : Issuers tiers (AWS PCA, Google CA, etc.)

### 2. Certificate

La ressource Certificate décrit un certificat désiré. C'est la ressource principale avec laquelle les utilisateurs interagissent.

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-com-cert
  namespace: default
spec:
  # Nom du Secret où stocker le certificat
  secretName: example-com-tls
  
  # Durée de validité du certificat
  duration: 2160h  # 90 jours
  
  # Renouveler 15 jours avant expiration
  renewBefore: 360h
  
  # Référence vers l'Issuer à utiliser
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  
  # Informations du certificat
  commonName: example.com
  dnsNames:
    - example.com
    - www.example.com
  
  # Subject Alternative Names (optionnel)
  ipAddresses:
    - 192.168.1.1
  uris:
    - spiffe://cluster.local/ns/default/sa/myapp
  
  # Usages du certificat
  usages:
    - digital signature
    - key encipherment
    - server auth
    - client auth
  
  # Clé privée
  privateKey:
    algorithm: RSA
    encoding: PKCS1
    size: 2048
    rotationPolicy: Always
```

### 3. CertificateRequest

Ressource de bas niveau créée automatiquement par cert-manager lors d'une demande de Certificate. Elle contient le CSR brut.

```yaml
apiVersion: cert-manager.io/v1
kind: CertificateRequest
metadata:
  name: example-com-cert-abcd123
  namespace: default
spec:
  request: LS0tLS1CRUdJTi...  # CSR encodé en base64
  duration: 2160h
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  usages:
    - digital signature
    - key encipherment
```

**Note :** Les utilisateurs n'ont généralement pas besoin de créer cette ressource manuellement.

### 4. Order et Challenge (pour ACME)

Ces ressources sont créées automatiquement lors de l'utilisation d'un Issuer ACME (Let's Encrypt).

**Order** : Représente une commande de certificat ACME
```yaml
apiVersion: acme.cert-manager.io/v1
kind: Order
metadata:
  name: example-com-cert-order
  namespace: default
spec:
  request: LS0tLS1CRUdJTi...
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - example.com
```

**Challenge** : Représente un challenge de validation ACME (HTTP-01 ou DNS-01)
```yaml
apiVersion: acme.cert-manager.io/v1
kind: Challenge
metadata:
  name: example-com-cert-challenge
  namespace: default
spec:
  type: HTTP-01
  dnsName: example.com
  token: abcd1234
  key: xyz789
  solver:
    http01:
      ingress:
        class: nginx
```


Voici le processus complet de création d'un certificat :

1. **Création de Certificate** : L'utilisateur crée une ressource Certificate
2. **Génération de clé privée** : cert-manager génère une clé privée
3. **Création de CertificateRequest** : Un CSR est généré et encapsulé
4. **Soumission à l'Issuer** : Le CSR est envoyé à l'autorité de certification
5. **Validation** (si ACME) : Création d'Order et Challenges pour prouver la propriété du domaine
6. **Signature** : L'autorité signe le certificat
7. **Stockage** : Le certificat et la clé sont stockés dans un Secret Kubernetes
8. **Surveillance** : cert-manager surveille l'expiration et renouvelle automatiquement

## Types de validation ACME

Pour Let's Encrypt et autres ACME, il existe deux méthodes de validation :

### HTTP-01 Challenge
Prouve que vous contrôlez le domaine en servant un fichier spécifique via HTTP.

```yaml
solvers:
- http01:
    ingress:
      class: nginx
```

**Avantages :**
- Simple à configurer
- Fonctionne avec n'importe quel Ingress Controller

**Limitations :**
- Ne supporte pas les wildcards (*.example.com)
- Nécessite que le port 80 soit accessible publiquement

### DNS-01 Challenge
Prouve la propriété en créant un enregistrement DNS TXT.

```yaml
solvers:
- dns01:
    cloudflare:
      email: admin@example.com
      apiTokenSecretRef:
        name: cloudflare-api-token
        key: api-token
```

**Avantages :**
- Support des certificats wildcard
- Pas besoin d'exposition HTTP publique

**Limitations :**
- Configuration plus complexe
- Nécessite l'accès à l'API DNS

## Intégration avec les ressources Kubernetes

### Avec Ingress

cert-manager s'intègre nativement avec les ressources Ingress via des annotations :

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - example.com
    secretName: example-com-tls  # cert-manager créera ce Secret
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 80
```

### Avec Gateway API

Support natif pour la nouvelle Gateway API de Kubernetes :

```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: example-gateway
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
    tls:
      certificateRefs:
      - name: example-gateway-tls
```

### Certificats mTLS (Mutual TLS)

Le mTLS (Mutual TLS) est une méthode d'authentification bidirectionnelle où non seulement le client vérifie l'identité du serveur (comme dans TLS standard), mais le serveur vérifie également l'identité du client. C'est essentiel pour sécuriser les communications entre microservices dans une architecture moderne.

On peut configurer les objets certificats pour les lier à certains objets services Kubernetes

# Emetteurs de certificats pour CertManager

## Issuers Intégrés (In-tree)

cert-manager peut obtenir des certificats de diverses autorités de certification, notamment Let's Encrypt, HashiCorp Vault, et des PKI privées.

### 1. **ACME / Let's Encrypt**
- Certificats gratuits et automatisés
- Idéal pour les workloads publics
- Renouvellement automatique tous les 90 jours

### 2. **HashiCorp Vault**
Vault est un magasin de secrets multi-usage qui peut signer des certificats pour votre infrastructure PKI. Configuration via plusieurs méthodes d'authentification :
- **AppRole** : authentification basée sur des rôles
- **Kubernetes Auth** : utilisation des Service Accounts Kubernetes
- **JWT/OIDC** : pour les clusters avec OIDC activé
- **Token** : authentification par token direct

### 3. **Venafi**
- Solutions enterprise (TPP / TLS Protect Cloud)
- Gestion centralisée des certificats
- Conformité et audit avancés

## Issuers Externes (External/Out-of-tree)

Les issuers externes sont installés en déployant un pod supplémentaire dans votre cluster qui surveille les ressources CertificateRequest.

### 4. **AWS Private CA (AWS PCA)**
AWS Private CA Issuer est un projet open source qui fait le pont entre AWS Private CA et cert-manager, permettant à cert-manager de signer des demandes de certificats via AWS PCA.

### 5. **Google Cloud CA Service**
- Intégration native avec Google Cloud
- Gestion centralisée pour GKE

### 7. **Cloudflare Origin CA**
origin-ca-issuer est utilisé pour demander des certificats signés par Cloudflare Origin CA afin d'activer TLS entre le edge Cloudflare et vos workloads Kubernetes
- Idéal si vous utilisez Cloudflare comme CDN
- Certificats gratuits valides 15 ans

et d'autres...
