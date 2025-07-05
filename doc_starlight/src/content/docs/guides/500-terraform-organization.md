---
title: "TP partie 5 - Organisation et structure des projets Terraform"
description: "Guide TP partie 5 - Organisation et structure des projets Terraform"
sidebar:
  order: 8
---


Dans cette cinquième partie, nous allons apprendre à mieux organiser nos projets Terraform en étudiant les dépendances entre ressources et en restructurant notre code. Cette partie se concentre sur les bonnes pratiques d'organisation plutôt que sur de nouvelles fonctionnalités AWS.

## Étude des dépendances avec terraform graph

Commençons par analyser les dépendances entre nos ressources en utilisant la commande `terraform graph`.

### Génération du graphe de dépendances

Partez du code de la partie 4 (copiez le dossier ou commitez les changements). Dans le dossier part5, exécutez :

```bash
terraform init
terraform graph > dependencies.dot
```

Cette commande génère un fichier DOT (format GraphViz) qui décrit les relations entre toutes les ressources Terraform.

### Visualisation du graphe

Pour visualiser le graphe, vous pouvez utiliser GraphViz (si installé) ou des outils en ligne :

```bash
# Si GraphViz est installé
dot -Tpng dependencies.dot -o dependencies.png

# Ou copiez le contenu de dependencies.dot dans un visualiseur en ligne
# comme http://magjac.com/graphviz-visual-editor/
```

### Analyse des dépendances

Examinez le graphe généré. Vous devriez voir les dépendances suivantes :

- **aws_instance.web_server** dépend de **aws_subnet.public** et **aws_security_group.web_ssh_access**
- **aws_route_table_association.public** dépend de **aws_subnet.public** et **aws_route_table.public**
- **aws_route_table.public** dépend de **aws_vpc.main** et **aws_internet_gateway.main**
- **aws_internet_gateway.main** dépend de **aws_vpc.main**
- **aws_subnet.public** dépend de **aws_vpc.main**
- **aws_security_group.web_ssh_access** dépend de **aws_vpc.main**

Ces dépendances garantissent que Terraform crée les ressources dans le bon ordre et les détruit dans l'ordre inverse.

## Refactorisation : séparation des fichiers

Maintenant, nous allons refactoriser notre code monolithique en plusieurs fichiers thématiques pour améliorer la lisibilité et la maintenance.


- Créez un fichier `vpc.tf` et déplacez toutes les ressources réseau à l'intérieur :

```coffee
# VPC
...
# Internet Gateway
...
# Subnet public
...
# Route table
...
# Association subnet avec route table
...
# Security Group
r..
# Outputs réseau
output "vpc_id" {
  value = aws_vpc.main.id
}
output "subnet_id" {
  value = aws_subnet.public.id
}
```

### Serveur web

De même créez un fichier `webserver.tf` contenant l'instance EC2 et les ressources associées :

```coffee
# Data source pour l'AMI personnalisée
...
# Instance EC2
...
# Outputs webserver
output "instance_id" {
  value = aws_instance.web_server.id
}

output "instance_public_ip" {
  value = aws_instance.web_server.public_ip
}

output "web_url" {
  value = "http://${aws_instance.web_server.public_ip}"
}
```

### Main simplifié

Le fichier `main.tf` ne contient plus que les providers :

```coffee
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "eu-west-3"
  profile = "<awsprofile-votreprenom>"
}
```

Il devient le point d'entrée principal du projet, contenant les informations de configuration Terraform et le provider AWS.

### Vérification de la refactorisation

Testez la nouvelle structure :

```bash
# Vérifiez que la configuration est identique
terraform plan
```

**Résultat attendu** : `No changes. Your infrastructure matches the configuration.`

Cette vérification confirme que la refactorisation n'a introduit aucun changement fonctionnel - le code fait exactement la même chose, mais il est mieux organisé.

## Fichiers de structure projet

### versions.tf - Gestion des versions

Créez un fichier `versions.tf` pour centraliser les contraintes de versions :

```coffee
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

**Pourquoi un fichier versions.tf ?**

Ce fichier sépare les contraintes de versions du code fonctionnel, facilitant la maintenance et les mises à jour. Il garantit que tous les membres de l'équipe utilisent des versions compatibles de Terraform et des providers.

### variables.tf - Paramétrage

Créez un fichier `variables.tf` pour définir les variables d'entrée :

```coffee
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"
}

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "<awsprofile-votreprenom>"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "ssh_key_path" {
  description = "Path to SSH private key"
  type        = string
  default     = "~/.ssh/id_terraform"
}
```

**Avantages des variables :**

- **Réutilisabilité** : Le même code peut être utilisé pour différents environnements
- **Flexibilité** : Les valeurs peuvent être modifiées sans changer le code
- **Documentation** : Les descriptions expliquent l'usage de chaque paramètre
- **Validation** : Terraform peut valider les types et contraintes

Avec des variables d'entrées, notre projet devient une sorte de module fonctionnel un peu plus réutilisable plutôt qu'un simple description.

### Utilisation des variables

Modifiez vos fichiers pour utiliser les variables. Par exemple, dans `main.tf` :

```coffee
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}
```

Dans `vpc.tf` :

```coffee
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  # ... reste identique
}

resource "aws_subnet" "public" {
  cidr_block = var.public_subnet_cidr
  # ... reste identique
}
```

Dans `webserver.tf` :

```coffee
resource "aws_instance" "web_server" {
  instance_type = var.instance_type
  # ...
  
  connection {
    private_key = file(var.ssh_key_path)
    # ... reste identique
  }
}
```

## Conclusion : quelques bonnes pratiques d'organisation

### Convention de nommage des fichiers

- **main.tf** : Providers et configuration Terraform principale
- **variables.tf** : Toutes les variables d'entrée
- **versions.tf** : Contraintes de versions
- **outputs.tf** : Outputs globaux (optionnel si distribués dans les autres fichiers)
- **[service].tf** : Regroupement logique par service (vpc.tf, webserver.tf, database.tf, etc.)

### Séparation des responsabilités

Chaque fichier doit avoir une responsabilité claire :
- Infrastructure réseau séparée des applications
- Variables centralisées et documentées
- Outputs regroupés par domaine fonctionnel

### Commentaires et documentation

Ajoutez des commentaires pour expliquer les choix techniques non évidents et documentez les variables avec des descriptions claires.

## Déploiement et vérification

Testez votre nouvelle structure organisée :

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

La nouvelle structure doit produire exactement la même infrastructure que la partie 4, démontrant que l'organisation du code n'affecte pas le fonctionnement.

Dans la partie suivante, nous utiliserons cette structure organisée pour créer une architecture VPC multi-AZ plus complexe.