---
title: TP partie 2 - AMI personnalisée avec Packer
weight: 5
---

Dans cette deuxième partie de TP nous allons créer une AMI personnalisée avec Packer puis l'utiliser dans Terraform. Nous partons d'Ubuntu 24.04 et ajoutons une clé SSH publique.

## Structure du projet

```
part2_packer_ami/
├── packer/
│   └── ubuntu-custom.pkr.hcl
├── main.tf
└── part2.md
```

## Création de l'AMI avec Packer

Packer est un outil open-source qui permet de créer des images de machines automatiquement à partir d'une configuration déclarative. Dans cette partie nous allons créer une AMI Ubuntu 24.04 personnalisée avec une clé SSH publique pré-installée.

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
  default = "<tfuser>"
}

data "amazon-ami" "ubuntu" {
  filters = {
    name                = "ubuntu/images/hvm-ssd/ubuntu-*-24.04-amd64-server-*"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["099720109477"]
  region      = var.region
  profile     = var.profile
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "ubuntu-24.04-custom-{{timestamp}}"
  instance_type = "t2.micro"
  region        = var.region
  profile       = var.profile
  source_ami    = data.amazon-ami.ubuntu.id
  ssh_username  = "ubuntu"

  tags = {
    Name = "Ubuntu 24.04 Custom AMI"
    OS   = "Ubuntu"
    Version = "24.04"
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
      "echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBXHgv6fDeMM/zbqXpzdANeNbltG74+2Q1pBC9CXRc0M root@lxd-remote' | sudo tee /root/.ssh/authorized_keys",
      "sudo chmod 700 /root/.ssh",
      "sudo chmod 600 /root/.ssh/authorized_keys",
      "sudo chown -R root:root /root/.ssh",
      "echo 'Custom AMI build completed'"
    ]
  }
}
```

Ce fichier définit le plugin Amazon nécessaire, les variables de configuration (région et profil AWS), la recherche de l'AMI Ubuntu 24.04 de base, la configuration de construction et les commandes à exécuter pour personnaliser l'image (ajout de la clé SSH).

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
  profile = "<tfuser>"
}

data "aws_ami" "custom_ubuntu" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["ubuntu-24.04-custom-*"]
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

### Se connecter en SSH a notre serveur

Déverrouillez la clé ssh stagiaire que nous avons mis dans l'AMI avec :

```sh
ssh-add ~/.ssh/id_stagiaire
```

Puis se connecter avec :

```sh
ssh root@<ip publique de la sortie terraform>
```

Nous n'arrivons pas à nous connecter parce que l'ip publique 