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

## Workspaces et gestion multi-environnements

Les workspaces permettent de gérer plusieurs environnements (dev, staging, prod) avec le même code. Chaque workspace maintient son propre fichier d'état indépendant.

### Création et gestion des workspaces

Explorons les commandes de base des workspaces :

```bash
# Voir le workspace actuel
terraform workspace show

# Lister tous les workspaces
terraform workspace list

# Créer un nouveau workspace
terraform workspace new dev
terraform workspace new staging

# Changer de workspace
terraform workspace select dev
```

### Configuration avec des fichiers de variables

Pour gérer différents environnements, créez des fichiers de variables spécifiques. D'abord, ajoutez la variable `environment` dans votre `variables.tf` :

```coffee
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}
```

Créez ensuite un fichier `dev.tfvars` pour l'environnement de développement :

```coffee
aws_region           = "eu-west-3"
aws_profile          = "laptop"
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidr   = "10.0.1.0/24"
instance_type        = "t2.micro"
ssh_key_path         = "~/.ssh/id_terraform"
environment          = "dev"
```

Et un fichier `staging.tfvars` pour l'environnement de staging :

```coffee
aws_region           = "eu-west-3"
aws_profile          = "laptop"
vpc_cidr             = "10.1.0.0/16"
public_subnet_cidr   = "10.1.1.0/24"
instance_type        = "t3.small"
ssh_key_path         = "~/.ssh/id_terraform"
environment          = "staging"
```

Notez les différences entre les environnements : des plages CIDR distinctes (10.0.x.x vs 10.1.x.x) et des types d'instances différents (t2.micro vs t3.small).

### Modification des ressources pour supporter les environnements

Modifiez vos ressources pour inclure l'environnement dans les noms et tags. Dans `vpc.tf` :

```coffee
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  # ...

  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
  }
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
      "echo '<h1>Hello from ${var.environment}!</h1>' > /var/www/html/index.html",
      "echo 'Nginx installed in ${var.environment} environment'"
    ]
  }

  tags = {
    Name        = "${var.environment}-web-server"
    Environment = var.environment
  }
}
```

### Déploiement des différents environnements

```bash
# Déploiement environnement dev
terraform workspace select dev
terraform plan -var-file="dev.tfvars" -out=dev.tfplan
terraform apply dev.tfplan

# Déploiement environnement staging
terraform workspace select staging
terraform plan -var-file="staging.tfvars" -out=staging.tfplan
terraform apply staging.tfplan

# Vérification des états séparés
terraform workspace select dev
terraform state list

terraform workspace select staging
terraform state list
```

Vous avez maintenant deux infrastructures indépendantes avec des CIDRs différents et des tailles d'instances différentes.

### Gestion des états par workspace

Chaque workspace maintient son propre fichier d'état :

```bash
# Les états sont stockés dans
# terraform.tfstate.d/dev/terraform.tfstate
# terraform.tfstate.d/staging/terraform.tfstate

ls -la terraform.tfstate.d/
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

Cette partie vous a montré comment maîtriser la gestion de l'état Terraform, utiliser les workspaces pour des environnements multiples, et configurer un backend distant sécurisé. Ces compétences sont essentielles pour utiliser Terraform en production et en équipe.

Dans la partie suivante, nous utiliserons ces bases solides pour créer une architecture VPC multi-AZ plus complexe et hautement disponible.