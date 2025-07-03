---
title: TP partie 6 - État Terraform, workspaces et backends
weight: 9
---

Dans cette sixième partie, nous allons explorer en profondeur la gestion de l'état (state) dans Terraform, l'utilisation des workspaces pour gérer plusieurs environnements, et la configuration d'un backend distant pour une collaboration sécurisée.

## Étude de l'état Terraform

L'état Terraform est un fichier JSON qui maintient la correspondance entre votre configuration et les ressources réelles dans le cloud. Nous allons explorer cet élément fondamental de Terraform.

### Analyse du fichier d'état local

Partez du code de la partie 5 (copiez le dossier ou commitez les changements). Dans le dossier part6, déployez l'infrastructure pour créer un état :

```bash
terraform init
terraform plan -var-file="dev.tfvars" -out=tfplan
terraform apply tfplan
```

### Exploration via la CLI Terraform

Utilisez les commandes Terraform pour inspecter l'état :

```bash
# Lister toutes les ressources dans l'état
terraform state list

# Afficher les détails d'une ressource
terraform state show aws_vpc.main

# Afficher l'état complet en format lisible
terraform show

# Afficher l'état en format JSON
terraform show -json > state.json
```

Ces commandes permettent d'explorer l'état sans le modifier. Vous y trouverez les identifiants des ressources (IDs AWS), les métadonnées de création, les dépendances entre ressources et les attributs sensibles (marqués comme tels).

### Lecture directe du fichier terraform.tfstate

Examinez le fichier d'état brut :

```bash
# Lecture du fichier d'état (attention : lecture seule !)
cat terraform.tfstate | jq '.'

# Extraire uniquement les ressources
cat terraform.tfstate | jq '.resources'

# Voir la version du state schema
cat terraform.tfstate | jq '.version'
```

Le fichier d'état contient plusieurs éléments clés. La `version` indique le format du state, `terraform_version` la version de Terraform utilisée, `serial` un numéro pour la gestion de concurrence, `lineage` un UUID unique pour ce state, et `resources` la liste complète des ressources et leurs attributs.

**⚠️ Important :** Ne modifiez jamais directement le fichier d'état. Utilisez toujours les commandes Terraform.

### Commandes avancées d'état

```bash
# Importer une ressource existante dans l'état
# terraform import aws_vpc.main vpc-1234567890abcdef0

# Retirer une ressource de l'état sans la détruire
# terraform state rm aws_instance.web_server

# Déplacer une ressource dans l'état
# terraform state mv aws_instance.web_server aws_instance.web_server_renamed

# Remplacer une ressource
# terraform state replace-provider hashicorp/aws registry.terraform.io/hashicorp/aws
```

## Workspaces : cas d'usage et limitations

Les workspaces Terraform permettent de créer plusieurs instances isolées d'une même configuration, chacune avec son propre fichier d'état. Contrairement à une idée répandue, ils ne sont pas la solution idéale pour séparer des environnements critiques comme production et développement.

### Comprendre les workspaces

Par défaut, Terraform utilise un workspace nommé "default" :

```bash
# Voir le workspace actuel
terraform workspace show

# Créer et sélectionner un nouveau workspace
terraform workspace new feature-test
terraform workspace select feature-test

# Lister tous les workspaces
terraform workspace list
```

Chaque workspace possède son propre fichier d'état, stocké dans le même backend mais dans des chemins séparés.

### Cas d'usage appropriés pour les workspaces

Les workspaces sont particulièrement adaptés pour :

**Tests de branches de fonctionnalités** : Déployer temporairement une branche pour tests sans impacter l'environnement principal de développement.

**Déploiements multi-régions** : Déployer la même application dans plusieurs régions AWS avec des variations mineures.

**Environnements temporaires** : Créer des environnements éphémères pour des démonstrations ou des tests de charge.

**Variantes d'une même application** : Déployer plusieurs versions d'une application dans le même environnement (par exemple, différentes configurations pour différents clients).

### Exemple pratique : déploiements de fonctionnalités

Créons un exemple où les workspaces sont utilisés pour tester différentes branches. D'abord, ajoutez une variable pour identifier la fonctionnalité :

```coffee
variable "feature_name" {
  description = "Name of the feature being tested"
  type        = string
  default     = "main"
}
```

Créez un fichier `feature-a.tfvars` pour une fonctionnalité spécifique :

```coffee
aws_region           = "eu-west-3"
aws_profile          = "laptop"
vpc_cidr             = "10.100.0.0/16"
public_subnet_cidr   = "10.100.1.0/24"
instance_type        = "t2.micro"
ssh_key_path         = "~/.ssh/id_terraform"
feature_name         = "feature-payment-api"
```

### Utilisation avec terraform.workspace

Terraform expose le nom du workspace actuel via `terraform.workspace`. Modifiez vos ressources pour l'utiliser. Dans `vpc.tf` :

```coffee
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  # ...

  tags = {
    Name      = "${terraform.workspace}-vpc"
    Workspace = terraform.workspace
    Feature   = var.feature_name
  }
}

# Security Group avec nom unique par workspace
resource "aws_security_group" "web_ssh_access" {
  name        = "${terraform.workspace}-web-ssh-access"
  description = "Allow SSH and HTTP access for ${terraform.workspace}"
  vpc_id      = aws_vpc.main.id
  # ...
}
```

Et dans `webserver.tf` :

```coffee
resource "aws_instance" "web_server" {
  # ...
  
  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y nginx",
      "systemctl start nginx",
      "systemctl enable nginx",
      "echo '<h1>Feature: ${var.feature_name} (${terraform.workspace})</h1>' > /var/www/html/index.html"
    ]
  }

  tags = {
    Name      = "${terraform.workspace}-web-server"
    Workspace = terraform.workspace
    Feature   = var.feature_name
  }
}
```

### Déploiement de branches de fonctionnalités

```bash
# Déploiement de la branche feature-payment
terraform workspace new feature-payment
terraform plan -var-file="feature-a.tfvars" -out=feature.tfplan
terraform apply feature.tfplan

# Retour au workspace principal
terraform workspace select default

# Nettoyage après les tests
terraform workspace select feature-payment
terraform destroy -var-file="feature-a.tfvars"
terraform workspace select default
terraform workspace delete feature-payment
```

### Limitations des workspaces pour les environnements

Les workspaces présentent des limitations importantes pour la séparation d'environnements critiques :

**Même backend partagé** : Tous les workspaces utilisent le même backend S3, donc les mêmes permissions d'accès. Impossible d'isoler réellement production et développement.

**Manque de visibilité** : Le workspace actuel n'est pas visible dans le code. Un `terraform destroy` accidentel dans le mauvais workspace peut avoir des conséquences catastrophiques.

**Risque d'erreurs humaines** : Facile d'oublier dans quel workspace on se trouve et d'appliquer des changements au mauvais endroit.

**Pas de séparation des pipelines** : Impossible d'avoir des processus CI/CD différents par workspace.

### Alternative recommandée pour les environnements

Pour une vraie séparation dev/staging/prod, privilégiez :

```
# Structure de répertoires séparés
terraform-infra/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── backend.tf  # Backend S3 différent
│   │   └── terraform.tfvars
│   ├── staging/
│   │   ├── main.tf
│   │   ├── backend.tf  # Backend S3 différent
│   │   └── terraform.tfvars
│   └── prod/
│       ├── main.tf
│       ├── backend.tf  # Backend S3 différent
│       └── terraform.tfvars
└── modules/
    ├── vpc/
    └── webserver/
```

Cette approche offre une vraie isolation avec des backends séparés, des permissions différentes et des pipelines CI/CD distincts.

### Gestion des états par workspace

Chaque workspace maintient son propre fichier d'état. Pour un backend local :

```bash
# Les états sont stockés dans
# terraform.tfstate.d/feature-payment/terraform.tfstate
# terraform.tfstate.d/feature-auth/terraform.tfstate

ls -la terraform.tfstate.d/
```

Pour un backend S3, les états sont organisés avec le préfixe `env:` :
```
s3://bucket-name/env:/feature-payment/path/to/state
s3://bucket-name/env:/feature-auth/path/to/state
```

## Backend distant avec S3

Un backend distant permet le partage sécurisé de l'état entre plusieurs utilisateurs et systèmes CI/CD. Nous allons configurer un backend S3 avec verrouillage DynamoDB.

### Création de l'infrastructure backend

Créez d'abord les ressources AWS nécessaires avec un fichier temporaire `backend-setup.tf` :

```coffee
# Bucket S3 pour le state Terraform
resource "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-state-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "Terraform State Bucket"
    Environment = "shared"
  }
}

# Génération d'un suffixe aléatoire pour le bucket
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Versioning du bucket
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Chiffrement du bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Blocage des accès publics
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Table DynamoDB pour le verrouillage
resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = "terraform-state-lock"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform State Lock Table"
    Environment = "shared"
  }
}

# Outputs pour utilisation ultérieure
output "s3_bucket_name" {
  value = aws_s3_bucket.terraform_state.id
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.terraform_state_lock.name
}
```

Déployez ces ressources :

```bash
# Renommez temporairement les autres fichiers pour éviter les conflits
mkdir temp
mv vpc.tf webserver.tf temp/

# Déployez le backend
terraform init
terraform plan -out=backend.tfplan
terraform apply backend.tfplan

# Notez le nom du bucket S3 affiché dans les outputs
terraform output s3_bucket_name
```

### Configuration du backend S3

Créez un fichier `backend.tf` avec la configuration du backend distant :

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
    key            = "part6/terraform.tfstate"
    region         = "eu-west-3"
    profile        = "laptop"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

Remplacez `<YOUR-BUCKET-NAME>` par le nom réel du bucket créé lors de l'étape précédente.

### Migration vers le backend distant

```bash
# Restaurez vos fichiers de configuration
mv temp/* .
rmdir temp
rm backend-setup.tf

# Reinitialisez avec le nouveau backend
terraform init

# Terraform vous demandera si vous voulez migrer l'état
# Répondez "yes" pour copier l'état local vers S3
```

### Vérification du backend distant

```bash
# Vérifiez que l'état est maintenant sur S3
aws s3 ls s3://terraform-state-<YOUR-BUCKET-NAME>/part6/

# Vérifiez les workspaces
terraform workspace list

# Changez de workspace et observez les différents fichiers d'état
terraform workspace select staging
aws s3 ls s3://terraform-state-<YOUR-BUCKET-NAME>/env:/staging/part6/
```

### Avantages du backend distant

Le backend distant offre plusieurs avantages essentiels. La **collaboration** permet à plusieurs développeurs de travailler sur la même infrastructure en partageant l'état. Le **verrouillage** via DynamoDB empêche les modifications simultanées qui pourraient corrompre l'état. La **sécurité** est renforcée avec le chiffrement et le versioning dans S3. Enfin, la **sauvegarde** automatique conserve les versions précédentes de l'état.

### Test du verrouillage

Pour tester le mécanisme de verrouillage :

```bash
# Dans un premier terminal
terraform plan -var-file="dev.tfvars"

# Dans un second terminal (pendant que le premier est en cours)
terraform plan -var-file="dev.tfvars"
# Vous devriez voir un message de verrouillage
```

## Nettoyage et bonnes pratiques

### Commandes de nettoyage

Pour nettoyer les environnements de test :

```bash
# Détruire l'environnement dev
terraform workspace select dev
terraform destroy -var-file="dev.tfvars"

# Détruire l'environnement staging
terraform workspace select staging
terraform destroy -var-file="staging.tfvars"

# Détruire les ressources de backend (optionnel)
# Attention : cela supprimera définitivement vos états !
# terraform destroy
```

### Bonnes pratiques de gestion d'état

Pour la **sécurité**, utilisez toujours un backend distant pour les environnements partagés, chiffrez l'état au repos et en transit, limitez l'accès au bucket S3 et à la table DynamoDB, et ne commitez jamais les fichiers d'état dans Git.

Pour l'**organisation**, créez un workspace par environnement (dev, staging, prod), un backend S3 séparé par projet ou équipe, utilisez des préfixes de clés cohérents dans S3 et documentez la structure de vos workspaces.

Pour la **maintenance**, surveillez la taille des fichiers d'état, nettoyez régulièrement les anciens workspaces, sauvegardez les états critiques et testez régulièrement les procédures de restauration.

## Conclusion

Cette partie vous a montré comment maîtriser la gestion de l'état Terraform et configurer un backend distant sécurisé. Nous avons exploré les workspaces en détaillant leurs cas d'usage appropriés (tests de fonctionnalités, déploiements temporaires) et leurs limitations pour la séparation d'environnements critiques.

Points clés à retenir :
- L'état Terraform est le cœur de votre infrastructure et doit être protégé
- Les workspaces sont utiles pour des variations temporaires, pas pour isoler prod/dev
- Un backend S3 avec verrouillage DynamoDB est essentiel pour le travail en équipe
- Pour de vrais environnements séparés, utilisez des répertoires et backends distincts

Dans la partie suivante, nous utiliserons ces bases solides pour créer une architecture VPC multi-AZ complexe et hautement disponible.