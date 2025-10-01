---
title: "Cours - L'opérateur CertManager"
description: "Guide Cours - L'opérateur CertManager"
sidebar:
  order: 413
draft: true
---






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


## Architecture d'intégration typique

Voici comment ces systèmes s'intègrent généralement :

## Exemple : 

## Création d'un issuer personnalisé

Pour créer un issuer externe, le meilleur point de départ est probablement le Sample External Issuer, maintenu par l'équipe cert-manager.

Les issuers personnalisés permettent d'intégrer n'importe quelle CA interne ou solution propriétaire !

Voulez-vous un exemple plus détaillé pour une intégration spécifique (Vault, AWS PCA, etc.) ?