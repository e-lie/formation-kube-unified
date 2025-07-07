---
title: TP partie 7 - Backend S3 et collaboration
weight: 10
---

Dans cette septième partie, nous allons configurer un backend S3 distant avec verrouillage DynamoDB pour permettre la collaboration sécurisée entre développeurs et une gestion centralisée de l'état Terraform.

## Backend distant avec S3

Un backend distant permet le partage sécurisé de l'état entre plusieurs utilisateurs et systèmes CI/CD. Nous allons configurer un backend S3 avec verrouillage DynamoDB.

### Création de l'infrastructure backend

**⚠️ Important :** Le backend S3 doit être créé séparément avant d'être utilisé. Nous allons utiliser un projet distinct au niveau racine pour créer cette infrastructure.

L'infrastructure backend comprend :
- Un bucket S3 chiffré avec versioning pour stocker les états
- Une table DynamoDB pour le verrouillage d'état
- Des politiques de sécurité appropriées

### Configuration du backend S3

Dans notre projet principal, copiez le contenu de part6 vers part7 :

```bash
# Copiez la structure depuis part6
cp -r part6_terraform_state/* part7_backend_s3/
```

Créez un fichier `backend.tf` (et supprimez `versions.tf` qui est ici remplacé) avec la configuration du backend distant :

```coffee
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "terraform-state-<YOUR-BUCKET-NAME>"
    key            = "tp-fil-rouge-dev/terraform.tfstate"
    region         = "eu-west-3"
    profile        = "default"
    encrypt        = true
    use_lockfile   = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

**Important :** Remplacez `<YOUR-BUCKET-NAME>` par le nom réel du bucket créé par le projet `s3_backend`.

### Migration vers le backend distant

Avant de migrer, assurez-vous que votre infrastructure backend S3 est déployée :

```bash
# Vérifiez que le backend S3 existe
cd ../part7_annexe_s3_bucket_creation
terraform output

# Revenez au dossier part7
cd ../part7_backend_s3
```

Procédez à la migration :

```bash
# Initialisez avec le nouveau backend
terraform init

# Terraform vous demandera si vous voulez migrer l'état
# Répondez "yes" pour copier l'état local vers S3
```

### Vérification du backend distant

```bash
# Vérifiez que l'état est maintenant sur S3
aws s3 ls s3://terraform-state-<YOUR-BUCKET-NAME>/ --recursive

# Vérifiez les workspaces
terraform workspace list

# Changez de workspace et observez les différents fichiers d'état
terraform workspace new test-s3-lock
aws s3 ls s3://terraform-state-<YOUR-BUCKET-NAME>/ --recursive
```

### Déploiement avec backend distant

Déployez votre infrastructure avec le backend S3 :

```bash
# Planifiez et appliquez
terraform plan -out=tfplan
terraform apply tfplan

# Vérifiez l'état dans S3
aws s3 ls s3://terraform-state-<YOUR-BUCKET-NAME>/ --recursive
```

### Avantages du backend distant et collaboration en équipe

Le backend distant offre plusieurs avantages essentiels :

- **Collaboration** : Plusieurs développeurs peuvent travailler sur la même infrastructure en partageant l'état, évitant les conflits et les incohérences
- **Verrouillage** : Via DynamoDB, le système empêche les modifications simultanées qui pourraient corrompre l'état. Chaque opération terraform lock l'état pendant son exécution  
- **Sécurité** : Le chiffrement au repos et en transit protège les données sensibles. Les versions précédentes de l'état sont conservées pour la récupération
- **Partage d'état** : Tous les membres de l'équipe accèdent au même état centralisé, éliminant les divergences locales
- **Audit et traçabilité** : S3 conserve l'historique des modifications avec le versioning, permettant de tracer qui a modifié quoi et quand
- **Sécurité d'accès** : Les permissions IAM contrôlent l'accès au bucket et à la table DynamoDB, permettant une gestion fine des autorisations
- **Intégration CI/CD** : Les pipelines d'intégration continue peuvent accéder à l'état partagé pour les déploiements automatisés

### Le mécanisme de lock file

Le paramètre `use_lockfile = true` active explicitement le système de verrouillage d'état de Terraform, tandis que `dynamodb_table` spécifie où stocker les verrous. Voici comment cela fonctionne :

**Lock file** : Terraform crée un enregistrement de verrouillage temporaire dans la table DynamoDB spécifiée qui empêche les modifications simultanées de l'état. Ce verrou contient :
- L'ID de l'opération en cours
- L'horodatage du début de l'opération  
- L'utilisateur qui a acquis le verrou
- Les informations sur l'environnement d'exécution

**Cycle de vie du verrou** :
1. **Acquisition** : Terraform tente d'acquérir le verrou au début de chaque opération (`plan`, `apply`, `destroy`)
2. **Maintien** : Le verrou est maintenu pendant toute la durée de l'opération
3. **Libération** : Le verrou est automatiquement libéré à la fin de l'opération (succès ou échec)

**Gestion des conflits** : Si une seconde opération tente de modifier le même état, elle attendra que le premier verrou soit libéré ou affichera une erreur après un timeout.

### Test du verrouillage

Pour tester le mécanisme de verrouillage, ouvrez deux terminaux :

```bash
# Terminal 1 - Lancez une opération longue
terraform worspace list (assurez vous d'etre dans test-s3-lock)
terraform destroy -auto-approve && terraform apply -auto-approve

# Terminal 2 - Tentez une opération simultanée
terraform plan
# Vous devriez voir un message de verrouillage
```

Le second terminal affichera un message similaire à :
```
Acquiring state lock. This may take a few moments...
Error: Error acquiring the state lock
```


### Exemple de workflow collaboratif

```bash
# Développeur A - Crée une branche et un workspace
git checkout -b feature-api-v2
terraform workspace new feature-api-v2
terraform plan -var-file="feature-api.tfvars" -out=feature.tfplan
terraform apply feature.tfplan

# Développeur B - Travaille sur une autre fonctionnalité (pas de verrouillage meme si meme etat car workspaces differents)
git checkout -b feature-ui-update
terraform workspace new feature-ui-update
terraform plan -var-file="feature-ui.tfvars" -out=feature.tfplan
terraform apply feature.tfplan

# Après validation, nettoyage
terraform workspace select feature-api-v2
terraform destroy -var-file="feature-api.tfvars"
terraform workspace select default
terraform workspace delete feature-api-v2
```

Cette partie vous a montré comment configurer et utiliser un backend S3 distant avec verrouillage DynamoDB pour la collaboration sécurisée. Le backend distant est essentiel pour le travail en équipe et la gestion sécurisée de l'infrastructure.

## Alternatives pour le backend

