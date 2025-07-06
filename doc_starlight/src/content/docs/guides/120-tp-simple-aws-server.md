---
title: "TP partie 1 - server simple avec AWS"
description: "Guide TP partie 1 - server simple avec AWS"
sidebar:
  order: 120
---



Dans cette première partie de TP nous allons provisionner un simple serveur ubuntu avec AWS. C'est un peu un hello world de terraform.


## Un déploiement avec un simple fichier

Créez un dossier TP1 et ouvrez le dans VSCode. Créez à l'intérieur un fichier `main.tf`.

- initialisez le un dépot git avec `git init`

- Ajoutez un fichier `.gitignore` avec le contenu suivant adapté à terraform :

```
# Local .terraform directories
**/.terraform/*

hashicorp

# .tfstate files
*.tfstate
*.tfstate.*

# Crash log files
crash.log
crash.*.log

# Exclude all .tfvars files, which are likely to contain sensitive data, such as
# password, private keys, and other secrets. These should not be part of version 
# control as they are data points which are potentially sensitive and subject 
# to change depending on the environment.
*.tfvars
*.tfvars.json

# Ignore override files as they are usually used to override resources locally and so
# are not checked in
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# Include override files you do wish to add to version control using negated pattern
# !example_override.tf

# Include tfplan files to ignore the plan output of command: terraform plan -out=tfplan
# example: *tfplan*

# Ignore CLI configuration files
.terraformrc
terraform.rc
```

Pour pouvoir utiliser le provider AWS nous devons d'abord définir une dépendance au provider terraform avec le code suivant :

```coffee
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

- `terraform {}` : Bloc de configuration global de Terraform
- `required_providers` : Définit les providers nécessaires
- `source` : Registre officiel HashiCorp pour le provider AWS
- `version` : Version ~> 5.0 (compatible avec 5.x mais pas 6.x)

### Configuration du provider AWS

Pour nous connecter au provider AWS il faut bien sur un compte de cloud chez ce fournisseur et une façon de nous authentifier à son API. Il existe de nombreuses façon de faire cela mais les plus classiques sont :

- utiliser des credentials au format:

```coffee
  access_key = "my-access-key"
  secret_key = "my-secret-key"
```

Cela permet de se connecter sans dépendre de la CLI AWS mais nécessite de gérer ces crédentials comme des secrets et éviter absolument de les ajouter au dépot Git. On pourrait également les fournir en ligne de commande ou sous forme de variables d'environnement au moment d'executer le code terraform.


Une autre méthode classique, souvent plus simple et sécure consiste a utiliser un profil de connexion configuré au niveau de la CLI AWS.

- Vérifiez que vous avez bien un profil awscli a votre nom préconfiguré sur la VM en lançant:

```
aws configure list-profiles
aws s3 ls --profile <votreprenom> # ne devrait pas renvoyer d'erreur (rien du tout en fait)
```

- `export AWS_PROFILE=mon-profil` permet de définir le profil par défaut pour le shell en cours pour éviter de devoir ajouter l'argument --profile

- Vous pouvez ensuite ajouter le bloc de code suivant en remplaçant le nom du profil par le votre :


```coffee
provider "aws" {
  region = "us-east-1"
  profile = "<awsprofile-votreprenom>"
}
```
- `provider "aws"` : Configuration du provider AWS
- `region` : Région AWS où créer les ressources (Virginie du Nord)

### Ressource instance EC2

Nous pouvons ensuite ajouter un bloc resource pour demander la création d'une instance (un serveur) :

```coffee
resource "aws_instance" "web_server" {
  ami           = "<identifiant d'un image server>"
  instance_type = "t2.micro"

  tags = {
    Name = "Simple Web Server"
  }
}
```
- `resource "aws_instance"` : Création d'une instance EC2
- `ami` : Une AMI (Amazon Machine Image) est un modèle préconfiguré qui contient toutes les informations nécessaires pour lancer une instance EC2 dans AWS.
- `instance_type` : Type t2.micro (utilisable dans le free tier amazon)
- `tags` : Métadonnées pour identifier la ressource et la retrouver ensuite dans le cloud

### 3. Source de données AMI Ubuntu

Il nous faut donc récupérer l'identifiant d'une image de VM amazon. La bonne pratique pour cela est d'utiliser une source donnée terraform ou block `data`. Ce bloc déclenchera un appel à l'API pour récupérer dynamiquement l'identifiant de l'image ce qui permet d'avoir un identifiant a jour et de changer facilement l'image de base pour nos VM a runtime.

```coffee
data "aws_ami" "ubuntu" {
  most_recent = true
  # "099720109477" is Canonical's official AWS account ID
  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
```

- `data "aws_ami"` : Recherche d'une AMI existante
- `most_recent = true` : Prend la version la plus récente
- `owners` : ID du compte Canonical (créateur d'Ubuntu)
- Premier `filter` : Recherche les AMIs Ubuntu 22.04 LTS
- Deuxième `filter` : Virtualisation hardware (HVM)


Maintenant il nous faut modifier le paramètre `ami` pour l'instance de VM en utilisant l'identifiant récupéré par le block data:

```coffee
ami = data.aws_ami.ubuntu.id
```


### 5. Sorties (Outputs)

Ajoutez les sorties suivantes pour afficher des informations concernant la resource créé (la sortie de votre module terraform)

```coffee
output "instance_id" {
  value = aws_instance.web_server.id
}

output "instance_public_ip" {
  value = aws_instance.web_server.public_ip
}

output "instance_public_dns" {
  value = aws_instance.web_server.public_dns
}
```

- `instance_id` : ID unique de l'instance
- `instance_public_ip` : Adresse IP publique
- `instance_public_dns` : Nom DNS public

## Commandes de déploiement

Executons et observons le résultat des commandes classiques

1. `terraform init`
2. `terraform plan` 
3. `terraform apply`


Pour vérifier que notre serveur a bien été créé on peut utiliser la CLI: 

`aws ec2 describe-instances --profile votreprenom`
