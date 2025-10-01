---
title: Cours - L'opérateur CertManager
draft: true
---



# Cours : cert-manager pour Kubernetes

## Introduction

cert-manager est un contrôleur Kubernetes natif qui automatise la gestion et le renouvellement des certificats TLS. Il transforme la gestion des certificats en ressources Kubernetes déclaratives, éliminant ainsi les processus manuels fastidieux et les risques d'expiration de certificats.

### Pourquoi cert-manager ?

**Problèmes sans cert-manager :**
- Processus manuel de génération de CSR (Certificate Signing Request)
- Soumission manuelle aux autorités de certification
- Surveillance manuelle des dates d'expiration
- Renouvellement manuel et redéploiement
- Risque d'oubli → expiration → interruption de service

**Avantages avec cert-manager :**
- Automatisation complète du cycle de vie des certificats
- Renouvellement automatique avant expiration
- Intégration native avec Kubernetes
- Support de multiples sources de certificats
- Gestion déclarative via YAML

## Architecture générale

cert-manager fonctionne selon un modèle de réconciliation continue typique de Kubernetes. Il surveille les ressources qu'il gère et s'assure que l'état réel correspond à l'état désiré.

### Composants principaux

**1. cert-manager Controller**
Le contrôleur principal qui orchestre la création et le renouvellement des certificats.

**2. Webhook**
Valide et mute les ressources cert-manager lors de leur création/modification.

**3. CA Injector**
Injecte automatiquement les CA bundles dans les ressources qui en ont besoin (webhooks, API services).

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

**Types d'Issuers disponibles :**
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

**Champs importants :**
- `secretName` : Où le certificat sera stocké
- `issuerRef` : Quel Issuer utiliser
- `dnsNames` : Noms de domaine du certificat
- `duration` : Durée de validité
- `renewBefore` : Quand déclencher le renouvellement

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

**Challenge** : Représente un défi de validation ACME (HTTP-01 ou DNS-01)
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

## Flux de travail général

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

## Cas d'usage avancés

### Certificats mTLS (Mutual TLS)

Pour l'authentification mutuelle entre services :

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: service-client-cert
spec:
  secretName: service-client-tls
  issuerRef:
    name: internal-ca
    kind: ClusterIssuer
  usages:
    - digital signature
    - key encipherment
    - client auth  # Important pour mTLS
  dnsNames:
    - service-a.default.svc.cluster.local
```

### Rotation automatique des certificats

cert-manager gère automatiquement la rotation :

```yaml
spec:
  renewBefore: 720h  # Renouveler 30 jours avant expiration
  privateKey:
    rotationPolicy: Always  # Régénérer la clé à chaque renouvellement
```

### Certificats avec SAN multiples

Support de plusieurs types de Subject Alternative Names :

```yaml
spec:
  dnsNames:
    - example.com
    - "*.example.com"
  ipAddresses:
    - 192.168.1.1
  uris:
    - spiffe://cluster.local/ns/default/sa/myapp
  emailAddresses:
    - admin@example.com
```

## Monitoring et debugging

### Vérifier l'état d'un Certificate

```bash
kubectl get certificate example-com-cert
kubectl describe certificate example-com-cert
```

### Vérifier les CertificateRequests

```bash
kubectl get certificaterequest
kubectl describe certificaterequest example-com-cert-xxxxx
```

### Logs du contrôleur

```bash
kubectl logs -n cert-manager deploy/cert-manager
```

### Événements

```bash
kubectl get events --sort-by='.lastTimestamp' | grep cert-manager
```

## Bonnes pratiques

### 1. Utiliser ClusterIssuer pour la production
Évite la duplication de configuration dans chaque namespace.

### 2. Configurer renewBefore approprié
Recommandation : 1/3 de la durée du certificat
- Certificat de 90 jours → renewBefore: 30 jours (720h)

### 3. Séparer staging et production
Utilisez l'environnement staging de Let's Encrypt pour les tests afin d'éviter les limites de taux.

### 4. Surveiller les expirations
Même avec cert-manager, mettez en place des alertes de secours.

### 5. Utiliser des ServiceAccounts dédiés
Pour les issuers externes (Vault, AWS PCA), utilisez des ServiceAccounts avec permissions minimales.

### 6. Backup des certificats sensibles
Bien que cert-manager les renouvelle, sauvegardez les certificats critiques.

### 7. Documenter vos Issuers
Ajoutez des annotations et labels pour identifier la source et l'usage.

## Dépannage courant

### Certificat non créé
- Vérifier que l'Issuer existe et est Ready
- Vérifier les événements du Certificate
- Vérifier les logs du contrôleur

### Challenge ACME échoue
- HTTP-01 : Vérifier que l'Ingress est accessible publiquement
- DNS-01 : Vérifier les credentials API DNS
- Vérifier les limites de taux Let's Encrypt

### Certificat non renouvelé
- Vérifier `renewBefore` vs `duration`
- Vérifier que le contrôleur fonctionne
- Vérifier les conditions du Certificate

## Installation

```bash
# Via kubectl
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Via Helm
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true
```

## Conclusion

cert-manager transforme la gestion des certificats TLS d'une tâche manuelle et risquée en un processus automatisé et fiable. En comprenant ses CRDs et son fonctionnement, vous pouvez sécuriser efficacement vos workloads Kubernetes tout en réduisant drastiquement la charge opérationnelle.

La clé du succès avec cert-manager réside dans :
- Une bonne compréhension du flux Certificate → CertificateRequest → Secret
- Le choix approprié d'Issuer pour votre contexte
- Une configuration de renouvellement préventive
- Un monitoring approprié pour détecter les problèmes rapidement