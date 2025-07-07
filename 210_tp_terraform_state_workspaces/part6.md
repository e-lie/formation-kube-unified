---
title: TP partie 6 - État Terraform et workspaces
weight: 9
---

Dans cette sixième partie, nous allons explorer en profondeur la gestion de l'état (state) dans Terraform et l'utilisation des workspaces pour gérer des environnements temporaires et des tests de fonctionnalités.

## Étude de l'état Terraform

L'état Terraform est un fichier JSON qui maintient la correspondance entre votre configuration et les ressources réelles dans le cloud. Nous allons explorer cet élément fondamental de Terraform.

### Analyse du fichier d'état local

Partez du code de la partie 5 (copiez le dossier ou commitez les changements). Dans le dossier part6, assurez vous du bon déploiement l'infrastructure (avoir un état) :

```bash
terraform init
terraform plan -var-file="feature-a.tfvars" -out=tfplan
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

### Structure du fichier terraform.tfstate

Ouvrez le fichier `terraform.tfstate` dans votre éditeur pour examiner sa structure. C'est un fichier JSON lisible qui contient toute l'information sur votre infrastructure :

```json
{
  "version": 4,
  "terraform_version": "1.5.7",
  "serial": 42,
  "lineage": "8a8b6c91-f6f7-c289-66f7-1b4e5dca8d50",
  "outputs": {
    "web_url": {
      "value": "http://13.37.42.10",
      "type": "string"
    }
  },
  "resources": [
    {
      "mode": "managed",
      "type": "aws_vpc",
      "name": "main",
      "provider": "provider[\"registry.terraform.io/hashicorp/aws\"]",
      "instances": [
        {
          "schema_version": 1,
          "attributes": {
            "id": "vpc-0123456789abcdef0",
            "cidr_block": "10.0.0.0/16",
            "tags": {
              "Name": "main-vpc"
            }
          }
        }
      ]
    }
  ]
}
```

**Éléments importants de la structure :**

- **version** : Version du format de fichier d'état (actuellement 4)
- **terraform_version** : Version de Terraform qui a créé cet état
- **serial** : Compteur incrémenté à chaque modification pour éviter les conflits
- **lineage** : UUID unique généré à la création de l'état, reste constant pendant toute sa vie
- **outputs** : Valeurs de sortie de votre configuration
- **resources** : Liste complète des ressources avec leurs attributs AWS réels

Chaque ressource contient :
- **mode** : "managed" (créée par Terraform) ou "data" (source de données)
- **type** et **name** : Correspondent à votre configuration (ex: `aws_vpc.main`)
- **provider** : Provider utilisé pour gérer cette ressource
- **instances** : Détails de chaque instance de la ressource avec tous ses attributs

### Le fichier terraform.tfstate.backup

Terraform crée automatiquement un fichier `terraform.tfstate.backup` qui contient la version précédente de l'état avant la dernière modification. Ce fichier de sauvegarde est crucial pour la récupération en cas de problème :

- Créé automatiquement à chaque `terraform apply` ou modification d'état
- Contient l'état exact d'avant la dernière opération
- Permet de revenir en arrière en cas de corruption ou d'erreur
- Ne doit pas être commité dans Git mais peut être sauvegardé séparément

En cas de problème grave avec l'état, vous pouvez restaurer manuellement :
```bash
# En dernier recours uniquement !
cp terraform.tfstate.backup terraform.tfstate
```

**⚠️ Important :** Ne modifiez jamais directement les fichiers d'état. Utilisez toujours les commandes Terraform pour toute manipulation.

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

Les workspaces Terraform permettent de créer plusieurs instances isolées d'une même configuration, chacune avec son propre fichier d'état. Contrairement à une idée répandue, ils ne sont pas la solution idéale pour séparer des environnements critiques comme production et développement. Il est facile de faire des erreurs avec en tout cas manuellement. Pour séparer dev et prod il on utilise plus classiquement deux backend séparés (avec un authentification et un code distinct qu'on peut factoriser avec des modules)

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

Chaque workspace possède son propre fichier d'état, stocké dans le même backend mais dans des chemins séparés (ici avec un backend local `terraform.state.d`).

### Cas d'usage appropriés pour les workspaces

Les workspaces sont particulièrement adaptés pour :

**Tests de branches de fonctionnalités** : Déployer temporairement une branche pour tests sans impacter l'environnement principal de développement.

**Déploiements multi-régions** : Déployer la même application dans plusieurs régions AWS avec des variations mineures.

**Environnements temporaires** : Créer des environnements éphémères pour des démonstrations ou des tests de charge.

**Variantes d'une même application** : Déployer plusieurs versions d'une application dans le même environnement (par exemple, différentes configurations pour différents clients).

### Adaptation du code pour les workspaces

Pour utiliser les workspaces efficacement, nous devons adapter notre code de la partie 5. Voici les modifications nécessaires :

**Ajout d'une nouvelle variable dans `variables.tf`** :

```coffee
variable "feature_name" {
  description = "Name of the feature being tested"
  type        = string
  default     = "main"
}
```

**Utilisation de `terraform.workspace` dans `vpc.tf`** :

Terraform expose le nom du workspace actuel via `terraform.workspace`. Modifiez toutes les ressources VPC pour utiliser cette valeur :

```coffee
# VPC avec nom dynamique par workspace
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name      = "${terraform.workspace}-vpc"    # Changé de "main-vpc"
    Workspace = terraform.workspace             # Nouveau tag
    Feature   = var.feature_name               # Nouveau tag
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name      = "${terraform.workspace}-igw"    # Changé de "main-igw"
    Workspace = terraform.workspace             # Nouveau tag
    Feature   = var.feature_name               # Nouveau tag
  }
}

# Subnet public
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true

  tags = {
    Name      = "${terraform.workspace}-public-subnet"  # Changé de "public-subnet"
    Workspace = terraform.workspace                     # Nouveau tag
    Feature   = var.feature_name                       # Nouveau tag
  }
}

# Route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name      = "${terraform.workspace}-public-route-table"  # Changé de "public-route-table"
    Workspace = terraform.workspace                          # Nouveau tag
    Feature   = var.feature_name                            # Nouveau tag
  }
}

# Security Group avec nom unique par workspace
resource "aws_security_group" "web_ssh_access" {
  name        = "${terraform.workspace}-web-ssh-access"      # Changé de "web-ssh-access"
  description = "Allow SSH and HTTP access for ${terraform.workspace}"
  vpc_id      = aws_vpc.main.id

  # ... règles inchangées ...

  tags = {
    Name      = "${terraform.workspace}-web-ssh-access"  # Changé de "Web and SSH Access"
    Workspace = terraform.workspace                      # Nouveau tag
    Feature   = var.feature_name                        # Nouveau tag
  }
}
```

**Modification de `webserver.tf`** :

```coffee
resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.custom_ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_ssh_access.id]

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file(var.ssh_key_path)
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y nginx",
      "systemctl start nginx",
      "systemctl enable nginx",
      # Modification importante : affichage du workspace et de la fonctionnalité
      "echo '<h1>Feature: ${var.feature_name} (${terraform.workspace})</h1>' > /var/www/html/index.html"
    ]
  }

  tags = {
    Name      = "${terraform.workspace}-web-server"  # Changé de "nginx-web-server-vpc"
    Workspace = terraform.workspace                  # Nouveau tag
    Feature   = var.feature_name                    # Nouveau tag
  }
}
```

**Création du fichier `feature-a.tfvars`** pour tester une fonctionnalité spécifique :

```coffee
aws_region           = "eu-west-3"
aws_profile          = "default"
vpc_cidr             = "10.100.0.0/16"
public_subnet_cidr   = "10.100.1.0/24"
instance_type        = "t2.micro"
ssh_key_path         = "~/.ssh/id_terraform"
feature_name         = "feature-payment-api"
```

Ces modifications permettent à chaque workspace d'avoir des noms de ressources uniques et d'afficher clairement dans quel contexte il fonctionne.

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

**Manque de visibilité et Risque d'erreurs humaines** : Le workspace actuel n'est pas visible dans le code. Un `terraform destroy` ou mauvaise modification dans le mauvais workspace peut avoir des conséquences catastrophiques.

**Pas de séparation des pipelines** : Plus difficile d'avoir des processus CI/CD différents par workspace.

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

Cette approche offre une vraie isolation avec des backends séparés, des permissions différentes et des pipelines CI/CD distincts. nous verrons cela dans un TP suivant.

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


Points clés à retenir :
- L'état Terraform est le cœur de votre infrastructure et doit être protégé
- Les workspaces sont utiles pour des variations temporaires, pas pour isoler prod/dev
- Pour de vrais environnements séparés, utilisez des répertoires et backends distincts
- Les workspaces permettent de tester des branches de fonctionnalités de manière isolée

Dans la partie suivante, nous configurerons un backend S3 distant avec verrouillage DynamoDB pour permettre la collaboration sécurisée entre développeurs.