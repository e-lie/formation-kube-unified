---
title: TP partie 5 - Architecture VPC avancée multi-AZ
weight: 8
---

Dans cette cinquième partie, nous allons construire une architecture VPC avancée multi-zones de disponibilité (multi-AZ) avec subnets publics et privés. Cette architecture reprend les concepts de la partie 4 et les étend pour créer une infrastructure hautement disponible et sécurisée.

## Qu'est-ce qu'un VPC AWS ?

Un VPC (Virtual Private Cloud) est un réseau virtuel dédié à votre application cloud. Il s'agit d'un environnement isolé logiquement du reste du cloud AWS où vous pouvez lancer vos ressources AWS dans un réseau virtuel que vous définissez. Vous avez un contrôle très large sur cet environnement réseau virtuel, y compris la sélection de votre propre plage d'adresses IP, la création de sous-réseaux et la configuration des tables de routage et des passerelles réseau.

### Concepts fondamentaux du VPC

#### CIDR (Classless Inter-Domain Routing)

Le CIDR est une méthode pour allouer des adresses IP et router des paquets IP. Dans AWS VPC, vous définissez votre espace d'adressage IP en utilisant la notation CIDR. Par exemple, `10.0.0.0/16` signifie que les 16 premiers bits sont fixes (10.0) et que vous avez 16 bits pour vos hôtes, ce qui vous donne 65 536 adresses IP possibles (de 10.0.0.0 à 10.0.255.255).

#### Subnets (Sous-réseaux)

Les subnets sont des segments de votre VPC où vous placez vos ressources. Chaque subnet est associé à une zone de disponibilité (AZ) spécifique. On distingue deux types de subnets :

- **Subnets publics** : Ont une route vers Internet via une Internet Gateway. Les ressources dans ces subnets peuvent avoir des adresses IP publiques.
- **Subnets privés** : N'ont pas de route directe vers Internet. Les ressources dans ces subnets ne sont accessibles que depuis l'intérieur du VPC.

#### Internet Gateway (IGW)

Une Internet Gateway est un composant VPC qui permet la communication entre les instances de votre VPC et Internet. C'est un service hautement disponible et redondant qui sert de point de sortie pour le trafic Internet de votre VPC.

#### NAT Gateway

Un NAT (Network Address Translation) Gateway permet aux instances dans un subnet privé d'initier des connexions sortantes vers Internet (pour les mises à jour, par exemple) tout en empêchant Internet d'initier des connexions entrantes vers ces instances. C'est essentiel pour la sécurité des ressources privées.

#### Route Tables

Les tables de routage contiennent des règles (routes) qui déterminent où le trafic réseau est dirigé. Chaque subnet doit être associé à une table de routage. La table de routage spécifie les chemins possibles pour le trafic sortant du subnet.

#### Security Groups

Les Security Groups agissent comme des pare-feu virtuels pour contrôler le trafic entrant et sortant au niveau de l'instance. Ils fonctionnent au niveau de l'instance et sont stateful (ils se souviennent des connexions établies).

## Architecture du VPC

![Architecture VPC](/partmaybe_vpc_networking/vpc-diagram.png)

Notre architecture VPC comprend les éléments suivants :

### Structure réseau

- **VPC principal** : Plage CIDR 10.0.0.0/16 (65 536 adresses IP)
- **2 zones de disponibilité** : Pour la haute disponibilité
- **4 subnets** :
  - 2 subnets publics (10.0.1.0/24 et 10.0.2.0/24)
  - 2 subnets privés (10.0.11.0/24 et 10.0.12.0/24)

### Composants de connectivité

- **1 Internet Gateway** : Pour l'accès Internet des subnets publics
- **2 NAT Gateways** : Un dans chaque subnet public pour la redondance
- **2 Elastic IPs** : Pour les NAT Gateways

### Tables de routage

- **1 table de routage publique** : Route par défaut vers l'Internet Gateway
- **2 tables de routage privées** : Une par AZ, route par défaut vers le NAT Gateway local

### Sécurité

- **Security Group Web** : Autorise SSH (22) et HTTP (80) depuis Internet
- **Security Group Privé** : Autorise SSH depuis le Security Group Web et MySQL (3306) depuis le VPC

## Avantages de cette architecture

### Isolation et sécurité

Le VPC crée un environnement réseau isolé où vous contrôlez totalement l'accès. Les ressources privées sont protégées derrière les NAT Gateways et ne sont pas directement accessibles depuis Internet.

### Haute disponibilité

En déployant des ressources dans plusieurs zones de disponibilité, l'architecture résiste aux pannes d'une zone complète. Si une AZ devient indisponible, l'application continue de fonctionner dans l'autre AZ.

### Évolutivité

La structure permet d'ajouter facilement de nouvelles ressources. Les plages CIDR choisies laissent de la place pour l'expansion future avec de nouveaux subnets si nécessaire.

### Séparation des responsabilités

La séparation entre subnets publics et privés permet de suivre les bonnes pratiques de sécurité en plaçant uniquement les ressources nécessitant un accès Internet direct dans les subnets publics.

## Construction progressive de l'architecture

Contrairement à la partie 4 où nous avons créé un VPC simple, nous allons maintenant construire une architecture complexe étape par étape pour bien comprendre chaque composant.

### Étape 1 : Base du projet

Commencez par reprendre la base de la partie 4 avec les providers et data sources :

```hcl
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
    values = ["ubuntu-22.04-custom-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}
```

### Étape 2 : VPC et Internet Gateway

Créez le VPC principal et son Internet Gateway :

```hcl
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}
```

### Étape 3 : Elastic IPs pour les NAT Gateways

Créez les IPs publiques fixes pour les NAT Gateways :

```hcl
resource "aws_eip" "nat" {
  count  = 2
  domain = "vpc"

  tags = {
    Name = "nat-eip-${count.index + 1}"
  }
}
```

### Étape 4 : Subnets publics et privés

Créez les subnets dans différentes zones de disponibilité :

```hcl
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${count.index + 1}"
    Type = "public"
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 11}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "private-subnet-${count.index + 1}"
    Type = "private"
  }
}
```

### Étape 5 : NAT Gateways

Créez les NAT Gateways pour l'accès Internet sortant des subnets privés :

```hcl
resource "aws_nat_gateway" "main" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "nat-gateway-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}
```

### Étape 6 : Tables de routage

Créez les tables de routage pour diriger le trafic correctement :

```hcl
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "private-route-table-${count.index + 1}"
  }
}
```

### Étape 7 : Associations des tables de routage

Associez les subnets aux bonnes tables de routage :

```hcl
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
```

### Étape 8 : Security Groups

Créez les groupes de sécurité pour les différents tiers :

```hcl
resource "aws_security_group" "web" {
  name        = "web-security-group"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.main.id

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
    Name = "web-security-group"
  }
}

resource "aws_security_group" "private" {
  name        = "private-security-group"
  description = "Security group for private instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "private-security-group"
  }
}
```

### Étape 9 : Instances EC2

Créez les instances dans les différents subnets :

```hcl
resource "aws_instance" "web" {
  count                  = 2
  ami                    = data.aws_ami.custom_ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public[count.index].id
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    echo "<h1>Web Server ${count.index + 1} - AZ: ${data.aws_availability_zones.available.names[count.index]}</h1>" > /var/www/html/index.html
    systemctl start nginx
    systemctl enable nginx
  EOF

  tags = {
    Name = "web-server-${count.index + 1}"
    Type = "public"
  }
}

resource "aws_instance" "private" {
  count                  = 2
  ami                    = data.aws_ami.custom_ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private[count.index].id
  vpc_security_group_ids = [aws_security_group.private.id]

  tags = {
    Name = "private-instance-${count.index + 1}"
    Type = "private"
  }
}
```

### Étape 10 : Outputs

Ajoutez les outputs pour voir les résultats :

```hcl
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "web_server_public_ips" {
  value = aws_instance.web[*].public_ip
}

output "web_urls" {
  value = [for ip in aws_instance.web[*].public_ip : "http://${ip}"]
}
```

## Déploiement

Pour déployer cette infrastructure :

```bash
terraform init
terraform plan
terraform apply
```

Une fois le déploiement terminé, vous pouvez accéder aux serveurs web via leurs IPs publiques affichées dans les outputs. Les instances privées ne sont accessibles qu'en passant par les instances publiques (architecture bastion).

## Coûts et optimisations

Cette architecture inclut des composants payants :
- **NAT Gateways** : Environ 0.045$/heure chacune
- **Elastic IPs** : Gratuite si associée, payante si non utilisée
- **Transfert de données** : Facturé pour le trafic sortant

Pour un environnement de développement, vous pourriez :
- Utiliser une seule NAT Gateway au lieu de deux
- Remplacer les NAT Gateways par des NAT Instances (moins chères mais nécessitent plus de maintenance)
- Arrêter les ressources quand elles ne sont pas utilisées

## Conclusion

Cette architecture VPC fournit une base solide pour déployer des applications sécurisées et hautement disponibles sur AWS. Elle suit les bonnes pratiques AWS en matière de sécurité, de disponibilité et d'évolutivité. Dans les prochaines parties, nous construirons sur cette base pour déployer des applications plus complexes.