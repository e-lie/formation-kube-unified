---
title: TP partie 3 - Provisionnement SSH avec Terraform
weight: 6
---

Dans cette troisième partie, nous allons découvrir comment utiliser les provisioners Terraform pour configurer automatiquement notre serveur après sa création. Nous allons installer et configurer Nginx en utilisant le provisioner SSH remote-exec.

## Structure du projet

```
part3_terraform_provisioner/
├── main.tf
└── part3.md
```

## Les provisioners Terraform

Les provisioners Terraform permettent d'exécuter des scripts ou des commandes sur une ressource locale ou distante après sa création. Ils sont utiles pour installer des logiciels, configurer des services ou effectuer toute autre tâche de configuration initiale. Cependant, il est important de noter que les provisioners sont considérés comme un dernier recours - il est généralement préférable d'utiliser des images pré-configurées (comme nous l'avons fait avec Packer) ou des outils de gestion de configuration dédiés.

### Configuration du fichier main.tf

Créez un fichier `main.tf` avec le contenu suivant qui reprend la base du projet part2 et ajoute un provisioner SSH :

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
    values = ["ubuntu-22.04-custom-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_security_group" "web_ssh_access" {
  name        = "web-ssh-access"
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

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file("~/.ssh/id_stagiaire")
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y nginx",
      "systemctl start nginx",
      "systemctl enable nginx",
      "echo '<h1>Hello from Terraform Provisioner!</h1>' > /var/www/html/index.html",
      "echo 'Nginx installed and configured successfully'"
    ]
  }

  tags = {
    Name = "Nginx Web Server"
    Type = "Provisioner-configured"
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

output "web_url" {
  value = "http://${aws_instance.web_server.public_ip}"
}
```

## Nouveaux éléments dans ce projet

### Security Group étendu

Le Security Group a été modifié pour autoriser non seulement le SSH (port 22) mais aussi le trafic HTTP (port 80) nécessaire pour accéder au serveur web Nginx. Cette configuration permet aux utilisateurs d'accéder au site web depuis n'importe quelle adresse IP.

### Bloc connection

Le bloc `connection` définit comment Terraform doit se connecter à l'instance pour exécuter les commandes. Il spécifie le type de connexion (SSH), l'utilisateur (root grâce à notre AMI personnalisée), la clé privée à utiliser et l'adresse IP de l'hôte. L'utilisation de `self.public_ip` permet de référencer dynamiquement l'IP publique de l'instance en cours de création.

### Provisioner remote-exec

Le provisioner `remote-exec` exécute une série de commandes sur l'instance distante via SSH. Dans notre cas, il met à jour les paquets système, installe Nginx, démarre le service, l'active au démarrage et crée une page d'accueil personnalisée. Les commandes sont exécutées dans l'ordre et si l'une échoue, le provisionnement s'arrête.

### Output web_url

Un nouvel output a été ajouté pour afficher directement l'URL du serveur web, facilitant ainsi l'accès au site après le déploiement.

## Déploiement et vérification

Exécutez les commandes suivantes pour déployer l'infrastructure :

```bash
terraform init
terraform plan
terraform apply
```

Une fois le déploiement terminé, Terraform affichera l'URL du serveur web. Vous pouvez vérifier que Nginx fonctionne en ouvrant cette URL dans votre navigateur. Vous devriez voir le message "Hello from Terraform Provisioner!".

## Points importants sur les provisioners

Les provisioners présentent certaines limitations qu'il est important de connaître. Ils ne s'exécutent qu'une seule fois lors de la création de la ressource et ne peuvent pas être réexécutés facilement. Si le provisionnement échoue, Terraform marque la ressource comme "tainted" et elle devra être recréée lors du prochain apply. De plus, les provisioners rendent l'infrastructure moins reproductible car leur succès peut dépendre de facteurs externes comme la disponibilité des paquets ou la connectivité réseau.

Pour ces raisons, il est généralement recommandé d'utiliser des images pré-configurées avec Packer (comme dans la partie 2) ou des outils de gestion de configuration comme Ansible pour des configurations plus complexes. Les provisioners restent utiles pour des configurations simples ou des prototypes rapides.