---
title: TP partie 11 - Terragrunt : Simplifier la gestion multi-environnements
weight: 14
---

Dans cette onzième partie, nous allons découvrir Terragrunt, un wrapper qui simplifie considérablement la gestion des infrastructures Terraform multi-environnements. Nous verrons comment Terragrunt résout les problèmes de duplication de code et de configuration que nous avons rencontrés dans la partie 10.

## Problématiques du Terraform vanilla

### Les défis identifiés en partie 10

Dans notre implémentation précédente avec Terraform vanilla, nous avons observé plusieurs problèmes :

**1. Duplication de code**
Nos fichiers `main.tf` sont identiques dans chaque environnement, seules les variables changent.

**2. Configuration backend répétitive**
Chaque environnement doit redéfinir la même configuration S3 avec seulement la clé qui change.

**3. Gestion manuelle des dépendances**
Si un module dépend d'un autre, nous devons gérer manuellement l'ordre d'exécution.

**4. Variables dispersées**
Les valeurs par défaut sont éparpillées entre `variables.tf` et `terraform.tfvars`.

### Pourquoi Terragrunt ?

Terragrunt apporte des solutions élégantes à ces problèmes :

- **DRY (Don't Repeat Yourself)** : Factorisation du code commun
- **Configuration centralisée** : Backend et provider configurés une seule fois
- **Gestion des dépendances** : Exécution automatique dans le bon ordre
- **Variables hiérarchiques** : Héritage intelligent des configurations

## Installation de Terragrunt

### Installation sur Linux/macOS

```bash
# Méthode 1 : Téléchargement direct
curl -LO https://github.com/gruntwork-io/terragrunt/releases/latest/download/terragrunt_linux_amd64
sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt
sudo chmod +x /usr/local/bin/terragrunt

# Méthode 2 : Via package manager
# Ubuntu/Debian
wget -qO- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
sudo apt update && sudo apt install terragrunt

# macOS
brew install terragrunt
```

### Vérification de l'installation

```bash
terragrunt --version
# Terragrunt v0.50.0
```

## Étude de notre structure Terragrunt

### Structure finale

Notre projet Terragrunt utilise cette organisation :

```sh
260_terragrunt/
├── part11.md                     # Ce tutoriel
├── _common/
│   └── terragrunt.hcl            # Configuration partagée
├── modules/                      # Modules Terraform copiés de part10
│   ├── vpc/
│   ├── webserver/
│   └── loadbalancer/
├── main-infrastructure/          # Module unifié
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── dev/
│   └── terragrunt.hcl           # Config environnement dev
├── staging/
│   └── terragrunt.hcl           # Config environnement staging
└── prod/
    └── terragrunt.hcl           # Config environnement prod
```

## Configuration commune : _common/terragrunt.hcl

Ce fichier définit la configuration partagée entre tous les environnements :

```coffee
# _common/terragrunt.hcl
remote_state {
  backend = "s3"
  config = {
    bucket         = "terraform-state-<YOUR-BUCKET-NAME>"
    key            = "tp-fil-rouge-${path_relative_to_include()}/terraform.tfstate"
    # path_relative_to_include() : Fonction Terragrunt qui retourne le chemin relatif
    # depuis le fichier _common/terragrunt.hcl jusqu'au fichier terragrunt.hcl 
    # qui l'inclut. => Depuis dev/terragrunt.hcl : retourne "dev"
    region         = "eu-west-3"
    profile        = "default"
    encrypt        = true
    use_lockfile   = true
    dynamodb_table = "terraform-state-lock"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Génération automatique du provider
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}
EOF
}

# Variables communes à tous les environnements
inputs = {
  aws_region   = "eu-west-3"
  aws_profile  = "default"
  ssh_key_path = "~/.ssh/id_terraform"
}
```

**Avantages de cette approche :**

- **Configuration S3 unique** : Plus de duplication de backend
- **Génération automatique** : backend.tf et provider.tf créés automatiquement
- **Variables communes** : Factorisation des valeurs partagées

## Module unifié : main-infrastructure/

### main-infrastructure/main.tf

Ce fichier combine tous nos modules existants :

```coffee
# main-infrastructure/main.tf
module "vpc" {
  source = "../modules/vpc"
  
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidr   = var.public_subnet_cidr
  public_subnet_cidr_2 = var.public_subnet_cidr_2
  workspace            = var.feature_name
  feature_name         = var.feature_name
  instance_count       = var.instance_count
}

module "webserver" {
  source = "../modules/webserver"
  
  instance_count    = var.instance_count
  instance_type     = var.instance_type
  subnet_id         = module.vpc.public_subnet_ids[0]
  security_group_id = module.vpc.web_servers_security_group_id
  ssh_key_path      = var.ssh_key_path
  workspace         = var.feature_name
  feature_name      = var.feature_name
}

module "loadbalancer" {
  source = "../modules/loadbalancer"
  
  instance_count     = var.instance_count
  workspace          = var.feature_name
  feature_name       = var.feature_name
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.public_subnet_ids
  security_group_ids = module.vpc.alb_security_group_ids
  instance_ids       = module.webserver.instance_ids
}
```

### main-infrastructure/variables.tf

```coffee
# main-infrastructure/variables.tf
variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
}

variable "public_subnet_cidr_2" {
  description = "CIDR block for second public subnet"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "ssh_key_path" {
  description = "Path to SSH private key"
  type        = string
}

variable "feature_name" {
  description = "Name of the feature being tested"
  type        = string
}

variable "instance_count" {
  description = "Number of web server instances"
  type        = number
}
```

### main-infrastructure/outputs.tf

```coffee
# main-infrastructure/outputs.tf
output "vpc_id" {
  description = "ID du VPC"
  value       = module.vpc.vpc_id
}

output "web_instance_ids" {
  description = "IDs des instances web"
  value       = module.webserver.instance_ids
}

output "web_public_ips" {
  description = "IPs publiques des instances web"
  value       = module.webserver.public_ips
}

output "web_url" {
  description = "URL du load balancer"
  value       = module.loadbalancer.web_url
}
```

## Configuration par environnement

### dev/terragrunt.hcl

```coffee
# dev/terragrunt.hcl
include "root" {
  path = find_in_parent_folders("_common/terragrunt.hcl")
}

terraform {
  source = "../main-infrastructure"
}

inputs = {
  feature_name   = "dev"
  instance_count = 1
  instance_type  = "t2.micro"
  
  # CIDR spécifiques à dev
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidr   = "10.0.1.0/24"
  public_subnet_cidr_2 = "10.0.2.0/24"
}
```

### staging/terragrunt.hcl

```coffee
# staging/terragrunt.hcl
include "root" {
  path = find_in_parent_folders("_common/terragrunt.hcl")
}

terraform {
  source = "../main-infrastructure"
}

inputs = {
  feature_name   = "staging"
  instance_count = 2
  instance_type  = "t2.small"
  
  # CIDR spécifiques à staging
  vpc_cidr             = "10.1.0.0/16"
  public_subnet_cidr   = "10.1.1.0/24"
  public_subnet_cidr_2 = "10.1.2.0/24"
}
```

### prod/terragrunt.hcl

```coffee
# prod/terragrunt.hcl
include "root" {
  path = find_in_parent_folders("_common/terragrunt.hcl")
}

terraform {
  source = "../main-infrastructure"
}

inputs = {
  feature_name   = "prod"
  instance_count = 3
  instance_type  = "t2.medium"
  
  # CIDR spécifiques à prod
  vpc_cidr             = "10.2.0.0/16"
  public_subnet_cidr   = "10.2.1.0/24"
  public_subnet_cidr_2 = "10.2.2.0/24"
}
```

## Déploiement avec Terragrunt

### Commandes de base

```bash
# Se placer dans un environnement spécifique
cd dev

# Initialiser l'environnement
terragrunt init

# Planifier les changements
terragrunt plan

# Appliquer l'infrastructure
terragrunt apply

# Détruire l'infrastructure
terragrunt destroy
```

### Commandes avancées

```bash
# Depuis la racine du projet
# Planifier tous les environnements
terragrunt run-all plan

# Appliquer tous les environnements
terragrunt run-all apply

# Détruire tous les environnements
terragrunt run-all destroy

# Exécuter depuis la racine sur un environnement spécifique
terragrunt plan --terragrunt-working-dir dev
terragrunt apply --terragrunt-working-dir staging
```

## Scripts d'automatisation

### scripts/deploy-all.sh

```bash
#!/bin/bash
set -e

echo "🚀 Déploiement de tous les environnements avec Terragrunt"

environments=("dev" "staging" "prod")

for env in "${environments[@]}"; do
    echo "📋 Déploiement de l'environnement: $env"
    
    cd "$env"
    
    # Initialisation
    terragrunt init
    
    # Plan
    terragrunt plan -out=tfplan
    
    # Protection pour la production
    if [ "$env" == "prod" ]; then
        echo "⚠️  ATTENTION: Déploiement en PRODUCTION!"
        read -p "Êtes-vous sûr ? (yes/no): " confirmation
        if [ "$confirmation" != "yes" ]; then
            echo "Déploiement de $env annulé."
            cd ..
            continue
        fi
    fi
    
    # Apply
    terragrunt apply tfplan
    
    echo "✅ Environnement $env déployé avec succès"
    cd ..
done

echo "🎉 Tous les environnements ont été déployés!"
```

### scripts/validate-all.sh

```bash
#!/bin/bash
set -e

echo "🔍 Validation de tous les environnements Terragrunt"

environments=("dev" "staging" "prod")

for env in "${environments[@]}"; do
    echo "Validation de l'environnement: $env"
    
    cd "$env"
    
    # Validation Terragrunt
    terragrunt validate
    
    # Plan pour vérifier la cohérence
    terragrunt plan -detailed-exitcode
    
    echo "✅ Environnement $env validé"
    cd ..
done

echo "✅ Tous les environnements sont valides!"
```

## Avantages démontrés de Terragrunt

### Comparaison avec Terraform vanilla

**Avant (Part 10 - Terraform vanilla) :**
```
250_multi_environnements/
├── environments/dev/
│   ├── main.tf           # 50 lignes (DUPLIQUÉ)
│   ├── variables.tf      # 30 lignes (DUPLIQUÉ)
│   └── terraform.tfvars  # 5 lignes
├── environments/staging/
│   ├── main.tf           # 50 lignes (DUPLIQUÉ)
│   ├── variables.tf      # 30 lignes (DUPLIQUÉ)
│   └── terraform.tfvars  # 5 lignes
└── environments/prod/
    ├── main.tf           # 50 lignes (DUPLIQUÉ)
    ├── variables.tf      # 30 lignes (DUPLIQUÉ)
    └── terraform.tfvars  # 5 lignes
```
**Total : 270 lignes dont 240 dupliquées (89% de duplication)**

**Après (Part 11 - Terragrunt) :**
```
260_terragrunt/
├── _common/terragrunt.hcl         # 40 lignes (configuration commune)
├── main-infrastructure/
│   ├── main.tf                    # 40 lignes (logique unique)
│   ├── variables.tf               # 30 lignes (variables unique)
│   └── outputs.tf                 # 15 lignes (outputs unique)
├── dev/terragrunt.hcl             # 15 lignes (spécifique)
├── staging/terragrunt.hcl         # 15 lignes (spécifique)
└── prod/terragrunt.hcl            # 15 lignes (spécifique)
```
**Total : 170 lignes, 0% de duplication**

### Gains mesurables

1. **Réduction de 37% du code** (270 → 170 lignes)
2. **Élimination complète de la duplication** (89% → 0%)
3. **Configuration backend centralisée** (1 vs 3 fichiers)
4. **Gestion des variables simplifiée** (héritage intelligent)

## Fonctionnalités avancées utilisées

### 1. Génération automatique de fichiers

```hcl
# Terragrunt génère automatiquement backend.tf et provider.tf
# Plus besoin de les maintenir manuellement dans chaque environnement
```

### 2. Variables hiérarchiques

```hcl
# _common/terragrunt.hcl (niveau racine)
inputs = {
  aws_region = "eu-west-3"    # Commun à tous
}

# dev/terragrunt.hcl (niveau environnement)
inputs = {
  instance_count = 1          # Spécifique à dev
  # aws_region hérité automatiquement
}
```

### 3. Référencement intelligent des chemins

```hcl
# find_in_parent_folders() trouve automatiquement _common/terragrunt.hcl
include "root" {
  path = find_in_parent_folders("_common/terragrunt.hcl")
}

# path_relative_to_include() génère automatiquement la clé S3
key = "tp-fil-rouge-${path_relative_to_include()}/terraform.tfstate"
```

## Test et validation de la solution

### Vérification de la structure

```bash
# Vérifier que les fichiers sont générés
cd dev
terragrunt init

ls -la
# backend.tf      <- Généré automatiquement
# provider.tf     <- Généré automatiquement
# .terragrunt-cache/
```

### Test des variables

```bash
# Vérifier l'héritage des variables
cd dev
terragrunt plan

# Expected: instance_count = 1, aws_region = "eu-west-3"

cd ../staging
terragrunt plan

# Expected: instance_count = 2, aws_region = "eu-west-3" (hérité)
```

### Validation des backend séparés

```bash
# Chaque environnement doit avoir sa propre clé S3
# dev:     tp-fil-rouge-dev/terraform.tfstate
# staging: tp-fil-rouge-staging/terraform.tfstate
# prod:    tp-fil-rouge-prod/terraform.tfstate
```

## Conclusion

### Quand choisir Terragrunt ?

**✅ Utilisez Terragrunt quand :**
- Vous gérez plusieurs environnements (dev/staging/prod)
- Vous avez de la duplication de code Terraform
- Vous voulez une configuration backend centralisée
- Votre équipe maîtrise les concepts Terraform de base

**❌ Restez sur Terraform vanilla quand :**
- Vous n'avez qu'un seul environnement
- Votre équipe apprend encore Terraform
- Vous avez des contraintes organisationnelles sur les outils

### Bénéfices mesurés dans ce TP

1. **Élimination de 89% de duplication de code**
2. **Réduction de 37% du volume total de code**
3. **Configuration backend unique et centralisée**
4. **Gestion des variables simplifiée avec héritage**
5. **Déploiement automatisé multi-environnements**

### Points clés à retenir

- **Terragrunt ne remplace pas Terraform**, il l'améliore
- **Structure claire** avec séparation configuration commune/spécifique
- **Génération automatique** des fichiers backend et provider
- **Variables hiérarchiques** avec héritage intelligent
- **Commandes simples** pour gérer plusieurs environnements

Dans un projet réel, Terragrunt devient indispensable dès que vous gérez plus d'un environnement, permettant de maintenir un code propre, sans duplication, et facilement évolutif.