---
title: TP partie 2 - AMI personnalisée avec Packer
weight: 5
---

Dans cette deuxième partie de TP nous allons créer une AMI personnalisée avec Packer puis l'utiliser dans Terraform. Nous partons d'Ubuntu 22.04 et ajoutons une clé SSH publique.

## Structure du projet a créer

```
part2_packer_ami/
├── packer/
│   └── ubuntu-custom.pkr.hcl
└── main.tf
```

## Génération d'une paire de clés SSH

Avant de créer notre AMI personnalisée, nous devons générer une paire de clés SSH qui sera utilisée pour l'accès à nos serveurs. Cette clé sera intégrée dans l'AMI et permettra une connexion sécurisée sans mot de passe.

### Création de la clé SSH

Générez une nouvelle paire de clés SSH sans phrase de passe avec la commande suivante :

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_terraform -N ""
```

Cette commande crée deux fichiers :
- `~/.ssh/id_terraform` : la clé privée (à garder secrète)
- `~/.ssh/id_terraform.pub` : la clé publique (à intégrer dans l'AMI)

Affichez le contenu de la clé publique pour l'utiliser dans Packer :

```bash
cat ~/.ssh/id_terraform.pub
```

## Création de l'AMI avec Packer

Packer est un outil open-source qui permet de créer des images de machines automatiquement à partir d'une configuration déclarative. Dans cette partie nous allons créer une AMI Ubuntu 22.04 personnalisée avec notre clé SSH publique pré-installée.

### Configuration Packer

Créez un dossier `packer` et ajoutez-y un fichier `ubuntu-custom.pkr.hcl` avec le contenu suivant :

```coffee
packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "region" {
  type    = string
  default = "eu-west-3"
}

variable "profile" {
  type    = string
  default = "<awsprofile-votreprenom>"
}

data "amazon-ami" "ubuntu" {
  filters = {
    name                = "ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["099720109477"]
  region      = var.region
  profile     = var.profile
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "ubuntu-22.04-custom-<votre-prenom>-{{timestamp}}"
  instance_type = "t2.micro"
  region        = var.region
  profile       = var.profile
  source_ami    = data.amazon-ami.ubuntu.id
  ssh_username  = "ubuntu"

  tags = {
    Name = "Ubuntu 22.04 Custom AMI"
    OS   = "Ubuntu"
    Version = "22.04"
  }
}

build {
  name = "ubuntu-custom"
  sources = ["source.amazon-ebs.ubuntu"]

  provisioner "shell" {
    inline = [
      "sleep 30",
      "sudo apt-get update",
      "sudo mkdir -p /root/.ssh",
      "echo '<VOTRE_CLÉ_PUBLIQUE>' | sudo tee /root/.ssh/authorized_keys",
      "sudo chmod 700 /root/.ssh",
      "sudo chmod 600 /root/.ssh/authorized_keys",
      "sudo chown -R root:root /root/.ssh",
      "echo 'Custom AMI build completed'"
    ]
  }
}
```

Ce fichier définit le plugin Amazon nécessaire, les variables de configuration (région et profil AWS), la recherche de l'AMI Ubuntu 22.04 de base, la configuration de construction et les commandes à exécuter pour personnaliser l'image. Remplacez `<VOTRE_CLÉ_PUBLIQUE>` par le contenu de votre fichier `~/.ssh/id_terraform.pub` obtenu précédemment.

### Construction de l'AMI

Une fois le fichier de configuration créé, vous pouvez construire votre AMI personnalisée avec les commandes suivantes :

```bash
cd packer
packer init ubuntu-custom.pkr.hcl
packer validate ubuntu-custom.pkr.hcl
packer build ubuntu-custom.pkr.hcl
```

## Utilisation de l'AMI avec Terraform

Maintenant que nous avons créé notre AMI personnalisée, nous allons l'utiliser dans un projet Terraform. Cette fois-ci au lieu de rechercher une AMI publique Ubuntu, nous allons utiliser notre propre AMI qui contient déjà la clé SSH configurée.


### Configuration du fichier main.tf

Modifiez un fichier `main.tf` à la racine du projet (pas dans le dossier packer) avec le contenu suivant :

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

data "aws_ami" "custom_ubuntu" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["ubuntu-22.04-custom-<votre-prenom>-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_instance" "web_server" {
  ami           = data.aws_ami.custom_ubuntu.id
  instance_type = "t2.micro"

  tags = {
    Name = "Custom Ubuntu Server"
    Type = "Packer-built"
  }
}

output "instance_id" {
  value = aws_instance.web_server.id
}

output "instance_public_ip" {
  value = aws_instance.web_server.public_ip
}

output "instance_public_dns" {
  value = aws_instance.web_server.public_dns
}

output "ami_id" {
  value = data.aws_ami.custom_ubuntu.id
}

output "ami_name" {
  value = data.aws_ami.custom_ubuntu.name
}
```

La différence principale avec la partie 1 est que le bloc `data "aws_ami"` utilise `owners = ["self"]` pour rechercher uniquement dans vos AMI personnelles au lieu des AMI publiques d'Ubuntu. Le filtre sur le nom correspond au pattern défini dans la configuration Packer.

### Se connecter en SSH à notre serveur

Pour vous connecter à l'instance, utilisez la clé privée que nous avons générée :

```sh
ssh -i ~/.ssh/id_terraform root@<ip publique de la sortie terraform>
```

Nous n'arrivons pas à nous connecter parce que l'instance EC2 n'a pas de règles de sécurité réseau autorisant l'accès SSH. Un Security Group AWS est un pare-feu virtuel qui contrôle le trafic réseau entrant et sortant des instances EC2.

## Configuration du Security Group

Pour autoriser l'accès SSH à notre instance, nous devons créer un Security Group avec les règles appropriées et l'associer à notre instance EC2.

### Ajout du Security Group au fichier main.tf

Modifiez votre fichier `main.tf` pour ajouter le Security Group avant la ressource instance :

```hcl
resource "aws_security_group" "web_ssh_access" {
  name        = "web-ssh-access-<votre-prenom>"
  description = "Allow SSH and HTTP access"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Web and SSH Access"
  }
}

resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.custom_ubuntu.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web_ssh_access.id]

  tags = {
    Name = "Custom Ubuntu Server"
    Type = "Packer-built"
  }
}
```

Ce Security Group définit deux règles d'entrée (`ingress`) : une qui autorise le trafic TCP sur le port 22 (SSH) et une autre sur le port 80 (HTTP) depuis n'importe quelle adresse IP (`0.0.0.0/0`). La règle de sortie (`egress`) autorise tout le trafic sortant. L'instance EC2 est maintenant associée à ce Security Group via le paramètre `vpc_security_group_ids`.

### Application des modifications

Après avoir modifié le fichier, appliquez les changements avec :

```bash
terraform plan
terraform apply
```

Terraform va créer le Security Group et modifier l'instance pour l'y associer. Une fois l'application terminée, vous devriez pouvoir vous connecter en SSH à votre instance.