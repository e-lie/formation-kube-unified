---
title: "TP partie 11 - Simplification multi-environnements avec Terragrunt"
description: "Guide TP partie 11 - Simplification multi-environnements avec Terragrunt"
sidebar:
  order: 260
---


Dans cette onzième partie, nous allons découvrir Terragrunt, un outil qui simplifie considérablement la gestion multi-environnements de Terraform. Nous verrons comment migrer notre structure de la Part 10 vers une approche Terragrunt plus maintenable.

## Introduction à Terragrunt

### Qu'est-ce que Terragrunt ?

Terragrunt est un wrapper autour de Terraform qui fournit des fonctionnalités supplémentaires pour :
- **DRY (Don't Repeat Yourself)** : Éviter la duplication de code entre environnements
- **Configuration centralisée** : Backend et provider partagés
- **Gestion des dépendances** : Orchestration entre modules
- **Hooks et validations** : Automatisation des tâches répétitives

### Problèmes résolus par Terragrunt

La structure Part 10 présentait plusieurs limitations :
- Duplication des fichiers `main.tf`, `variables.tf`, `outputs.tf`
- Configuration backend répétée dans chaque environnement
- Difficultés de maintenance lors de changements globaux
- Gestion manuelle des dépendances entre modules

## Installation de Terragrunt

### Installation sur Linux/macOS

```bash
# Télécharger la dernière version
TERRAGRUNT_VERSION="v0.53.0"
curl -LO "https://github.com/gruntwork-io/terragrunt/releases/download/${TERRAGRUNT_VERSION}/terragrunt_linux_amd64"

# Rendre exécutable et déplacer
chmod +x terragrunt_linux_amd64
sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt

# Vérifier l'installation
terragrunt --version
```

### Installation avec package managers

```bash
# Homebrew (macOS)
brew install terragrunt

# Chocolatey (Windows)
choco install terragrunt

# Arch Linux
yay -S terragrunt
```

## Conversion de la structure Part 10 vers Terragrunt

### Étape 1 : Analyser la structure existante

Partons de la structure Part 10 pour identifier ce qui peut être factorisé :

```bash
# Revenir dans le dossier Part 10 pour analyser
cd ../250_multi_environnements

# Examiner la duplication
diff environments/dev/main.tf environments/staging/main.tf
diff environments/staging/main.tf environments/prod/main.tf
```

**Observations :**
- Les fichiers `main.tf` sont identiques sauf pour le paramètre `workspace`
- La configuration backend est dupliquée
- La structure des modules est la même partout

### Étape 2 : Créer la structure Terragrunt

```bash
# Retourner au niveau parent et créer la structure Terragrunt
cd ..
mkdir -p 260_terragrunt

cd 260_terragrunt
mkdir -p {_common,dev,staging,prod}
mkdir -p modules
```

### Étape 3 : Copier et adapter les modules

```bash
# Copier les modules depuis Part 10
cp -r ../250_multi_environnements/modules/* modules/

# Les modules restent inchangés dans Terragrunt
```

### Étape 4 : Créer la configuration commune

Créez `_common/terragrunt.hcl` pour centraliser la configuration :

```bash
cat > _common/terragrunt.hcl << 'EOF'
# Configuration commune pour tous les environnements

# Configuration du backend S3
remote_state {
  backend = "s3"
  config = {
    bucket         = "terraform-state-<YOUR-BUCKET-NAME>"
    region         = "eu-west-3"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
    
    # La clé sera générée automatiquement par Terragrunt
    key = "${path_relative_to_include()}/terraform.tfstate"
  }
}

# Configuration Terraform commune
terraform {
  # Version minimale requise
  required_version = ">= 1.0"
  
  # Providers requis
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Variables communes à tous les environnements
inputs = {
  aws_region = "eu-west-3"
  aws_profile = "<awsprofile-votreprenom>"
  vpc_cidr = "10.0.0.0/16"
  public_subnet_cidr = "10.0.1.0/24"
  public_subnet_cidr_2 = "10.0.2.0/24"
  ssh_key_path = "~/.ssh/id_terraform"
}
EOF
```

### Étape 5 : Créer le module Terraform principal

Créez `main-infrastructure/main.tf` :

```bash
mkdir -p main-infrastructure

cat > main-infrastructure/main.tf << 'EOF'
# Configuration du provider AWS
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# Module VPC
module "vpc" {
  source = "../modules/vpc"
  
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidr   = var.public_subnet_cidr
  public_subnet_cidr_2 = var.public_subnet_cidr_2
  workspace            = var.environment
  feature_name         = var.feature_name
  instance_count       = var.instance_count
}

# Module Webserver
module "webserver" {
  source = "../modules/webserver"
  
  instance_count    = var.instance_count
  instance_type     = var.instance_type
  subnet_id         = module.vpc.public_subnet_ids[0]
  security_group_id = module.vpc.web_servers_security_group_id
  ssh_key_path      = var.ssh_key_path
  workspace         = var.environment
  feature_name      = var.feature_name
}

# Module Load Balancer
module "loadbalancer" {
  source = "../modules/loadbalancer"
  
  instance_count     = var.instance_count
  workspace          = var.environment
  feature_name       = var.feature_name
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.public_subnet_ids
  security_group_ids = module.vpc.alb_security_group_ids
  instance_ids       = module.webserver.instance_ids
}
EOF
```

### Étape 6 : Créer les variables du module principal

```bash
cat > main-infrastructure/variables.tf << 'EOF'
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

variable "environment" {
  description = "Environment name"
  type        = string
}
EOF
```

### Étape 7 : Créer les outputs du module principal

```bash
cat > main-infrastructure/outputs.tf << 'EOF'
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
EOF
```

### Étape 8 : Configurer chaque environnement

#### Environnement dev

```bash
cat > dev/terragrunt.hcl << 'EOF'
# Inclure la configuration commune
include "root" {
  path = find_in_parent_folders()
  expose = true
}

# Source du module Terraform
terraform {
  source = "../main-infrastructure"
}

# Variables spécifiques à l'environnement dev
inputs = {
  environment    = "dev"
  feature_name   = "dev"
  instance_count = 1
  instance_type  = "t2.micro"
}
EOF
```

#### Environnement staging

```bash
cat > staging/terragrunt.hcl << 'EOF'
# Inclure la configuration commune
include "root" {
  path = find_in_parent_folders()
  expose = true
}

# Source du module Terraform
terraform {
  source = "../main-infrastructure"
}

# Variables spécifiques à l'environnement staging
inputs = {
  environment    = "staging"
  feature_name   = "staging"
  instance_count = 2
  instance_type  = "t2.small"
}
EOF
```

#### Environnement prod

```bash
cat > prod/terragrunt.hcl << 'EOF'
# Inclure la configuration commune
include "root" {
  path = find_in_parent_folders()
  expose = true
}

# Source du module Terraform
terraform {
  source = "../main-infrastructure"
}

# Variables spécifiques à l'environnement prod
inputs = {
  environment    = "prod"
  feature_name   = "prod"
  instance_count = 3
  instance_type  = "t2.medium"
}
EOF
```

### Étape 9 : Créer le fichier terragrunt.hcl racine

```bash
cat > terragrunt.hcl << 'EOF'
# Configuration Terragrunt racine

# Import de la configuration commune
include {
  path = find_in_parent_folders("_common/terragrunt.hcl")
}

# Génération automatique des variables Terraform
generate "terraform_vars" {
  path      = "terraform.tfvars"
  if_exists = "overwrite"
  contents  = <<EOF
# Variables générées automatiquement par Terragrunt
# Ne pas modifier manuellement
aws_region = "${include.root.inputs.aws_region}"
aws_profile = "${include.root.inputs.aws_profile}"
vpc_cidr = "${include.root.inputs.vpc_cidr}"
public_subnet_cidr = "${include.root.inputs.public_subnet_cidr}"
public_subnet_cidr_2 = "${include.root.inputs.public_subnet_cidr_2}"
ssh_key_path = "${include.root.inputs.ssh_key_path}"
EOF
}

# Génération automatique de la configuration provider
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
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
EOF
}
EOF
```

## Utilisation de Terragrunt

### Commandes de base

```bash
# Dans un environnement spécifique
cd dev

# Init (remplace terraform init)
terragrunt init

# Plan (remplace terraform plan)
terragrunt plan

# Apply (remplace terraform apply)
terragrunt apply

# Destroy (remplace terraform destroy)
terragrunt destroy
```

### Commandes multi-environnements

```bash
# Depuis la racine du projet

# Exécuter plan sur tous les environnements
terragrunt run-all plan

# Exécuter apply sur tous les environnements
terragrunt run-all apply

# Exécuter destroy sur tous les environnements
terragrunt run-all destroy

# Valider tous les environnements
terragrunt run-all validate
```

### Vérification de la configuration

Testez la configuration Terragrunt :

```bash
# Vérifier la configuration de dev
cd dev
terragrunt plan

# Vérifier depuis la racine
cd ..
terragrunt run-all validate
```

**Résultat attendu** :
- Terragrunt génère automatiquement les fichiers `terraform.tfvars` et `provider.tf`
- Le backend S3 est configuré automatiquement avec des clés uniques
- Les plans montrent les mêmes ressources que la Part 10

## Fonctionnalités avancées de Terragrunt

### 1. Dépendances entre modules

```hcl
# Si vous aviez des modules avec dépendances
dependency "network" {
  config_path = "../network"
}

inputs = {
  vpc_id = dependency.network.outputs.vpc_id
}
```

### 2. Hooks pour automatisation

```hcl
# Dans terragrunt.hcl
terraform {
  before_hook "validate_aws_cli" {
    commands = ["init", "plan", "apply"]
    execute  = ["aws", "sts", "get-caller-identity"]
  }
  
  after_hook "notify_success" {
    commands = ["apply"]
    execute  = ["echo", "Deployment completed successfully!"]
  }
}
```

### 3. Variables d'environnement dynamiques

```hcl
# Configuration avec variables d'environnement
locals {
  environment = basename(get_terragrunt_dir())
  region      = "eu-west-3"
  
  # Tailles d'instance par environnement
  instance_types = {
    dev     = "t2.micro"
    staging = "t2.small"
    prod    = "t2.medium"
  }
}

inputs = {
  environment   = local.environment
  instance_type = local.instance_types[local.environment]
}
```

### 4. Configuration de backend par environnement

```hcl
# Backend différent par environnement
remote_state {
  backend = "s3"
  config = {
    bucket = "terraform-state-${local.environment}"
    key    = "${path_relative_to_include()}/terraform.tfstate"
    region = local.region
  }
}
```

## Migration depuis Part 10

### Script de migration automatique

Créez `scripts/migrate-from-part10.sh` :

```bash
cat > scripts/migrate-from-part10.sh << 'EOF'
#!/bin/bash
set -e

echo "🔄 Migration de Part 10 vers Terragrunt..."

# Créer le répertoire de scripts
mkdir -p scripts

# Sauvegarder les états existants
echo "📦 Sauvegarde des états existants..."
for env in dev staging prod; do
    if [ -d "../250_multi_environnements/environments/$env" ]; then
        cd "../250_multi_environnements/environments/$env"
        if [ -f "terraform.tfstate" ]; then
            terraform state pull > "../../../260_terragrunt/backup-${env}-$(date +%Y%m%d).tfstate"
            echo "État $env sauvegardé"
        fi
        cd - > /dev/null
    fi
done

# Importer les états dans Terragrunt
echo "📥 Import des états dans Terragrunt..."
for env in dev staging prod; do
    echo "Import de l'environnement $env..."
    cd "$env"
    
    # Initialiser Terragrunt
    terragrunt init
    
    # Importer l'état si la sauvegarde existe
    if [ -f "../backup-${env}-$(date +%Y%m%d).tfstate" ]; then
        cp "../backup-${env}-$(date +%Y%m%d).tfstate" terraform.tfstate
        echo "État $env importé"
    fi
    
    cd ..
done

echo "✅ Migration terminée!"
echo "Vous pouvez maintenant utiliser 'terragrunt' au lieu de 'terraform'"
EOF

chmod +x scripts/migrate-from-part10.sh
```

## Déploiement avec Terragrunt

### Déploiement séquentiel

```bash
# Déploiement manuel environnement par environnement
cd dev
terragrunt apply

cd ../staging  
terragrunt apply

cd ../prod
terragrunt apply
```

### Déploiement parallèle

```bash
# Déploiement parallèle de tous les environnements
terragrunt run-all apply --terragrunt-parallelism 3
```

### Déploiement avec approbation

```bash
# Plan global avec révision
terragrunt run-all plan

# Apply avec confirmation manuelle
terragrunt run-all apply --terragrunt-non-interactive false
```

## Comparaison Part 10 vs Part 11

### Avantages de Terragrunt

| Aspect | Part 10 (Terraform pur) | Part 11 (Terragrunt) |
|--------|--------------------------|----------------------|
| **Duplication** | 3 fois `main.tf` identiques | 1 seul `main.tf` |
| **Backend** | Configuration dupliquée | Configuration centralisée |
| **Maintenance** | Modifications multiples | Modification unique |
| **Déploiement** | Scripts bash personnalisés | Commandes intégrées |
| **Validation** | Manuelle par environnement | `run-all validate` |
| **Dépendances** | Gestion manuelle | Déclaration explicite |

### Structure finale

```
260_terragrunt/
├── _common/
│   └── terragrunt.hcl          # Configuration partagée
├── main-infrastructure/        # Module principal
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── modules/                    # Modules réutilisables
│   ├── vpc/
│   ├── webserver/
│   └── loadbalancer/
├── dev/
│   └── terragrunt.hcl         # Config spécifique dev
├── staging/
│   └── terragrunt.hcl         # Config spécifique staging
├── prod/
│   └── terragrunt.hcl         # Config spécifique prod
└── terragrunt.hcl             # Config racine
```

## Bonnes pratiques Terragrunt

### 1. Structure de répertoires

- `_common/` : Configurations partagées
- `modules/` : Modules Terraform réutilisables
- `{env}/` : Configurations spécifiques par environnement
- `global/` : Ressources globales (DNS, IAM)

### 2. Nommage des fichiers

- `terragrunt.hcl` : Configuration Terragrunt
- `terraform.tf` : Généré automatiquement
- `provider.tf` : Généré automatiquement

### 3. Variables et secrets

```hcl
# Variables d'environnement
inputs = {
  db_password = get_env("DB_PASSWORD", "default-value")
  api_key     = get_env("API_KEY")
}
```

### 4. Validation avant déploiement

```bash
# Toujours valider avant apply
terragrunt run-all validate
terragrunt run-all plan
terragrunt run-all apply
```

## Points clés à retenir

1. **DRY** : Terragrunt élimine la duplication de code
2. **Centralisation** : Configuration backend et provider partagée
3. **Simplicité** : Commandes `run-all` pour actions globales
4. **Flexibilité** : Hooks et fonctions avancées
5. **Compatibilité** : 100% compatible avec Terraform existant

## Ressources supplémentaires

- [Terragrunt Documentation](https://terragrunt.gruntwork.io/)
- [Terragrunt Best Practices](https://terragrunt.gruntwork.io/docs/getting-started/quick-start/)
- [Terragrunt vs Terraform Comparison](https://blog.gruntwork.io/terragrunt-how-to-keep-your-terraform-code-dry-and-maintainable-f61ae06959d8)

## Conclusion

Terragrunt simplifie considérablement la gestion multi-environnements en :
- Éliminant la duplication de code
- Centralisant la configuration commune
- Fournissant des outils d'orchestration puissants
- Maintenant la compatibilité avec Terraform

Cette approche est particulièrement adaptée aux organisations gérant de nombreux environnements et modules Terraform.