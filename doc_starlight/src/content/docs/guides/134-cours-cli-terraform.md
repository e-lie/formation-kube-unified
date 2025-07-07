---
title: "Cours - La CLI de Terraform"
description: "Guide Cours - La CLI de Terraform"
sidebar:
  order: 134
---



![](/134_cours_cli_terraform/images/terraform-ast-2.png)

![](/134_cours_cli_terraform/images/terraform-workflow-diff.png)

---

## Les IHM de Terraform

---


#### CLI

**L'outil en ligne de commande est le moyen d'accès le plus simple et essentiel pour apprendre et maîtriser Terraform.**

* Exposition progressive aux concepts et aux pratiques
* Approfondissement progressif de chaque commande selon le besoin
* Intégralité des opérations disponibles
---
#### Terraform Cloud / Enterprise 

**Une autre solution est Terraform Enterprise qui présente une interface HTML.**

![](/134_cours_cli_terraform/images/terraform-tf-cloud.png)


Terraform Cloud est le SASS proposé par la société Hashicorp pour cet outil.

Il offre de nombreux avantages pour le travail en équipe, comme par exemple l'intégration de GIT, des états d'infrastructure.

---

#### CDK for Terraform

**On peut également piloter Terraform avec un langage comme TypeScript, Python, Java, C#, ou Go.**

> https://developer.hashicorp.com/terraform/cdktf

```js
// SPDX-License-Identifier: MPL-2.0

// Importation des modules nécessaires pour CDKTF (Cloud Development Kit for Terraform)
import { Construct } from "constructs";
import { App, TerraformStack, TerraformOutput } from "cdktf";
import {
  DataAwsAmi,       // Pour récupérer des informations sur une AMI
  AwsProvider,      // Fournisseur AWS pour Terraform
  Instance,         // Ressource EC2 Instance
} from "@cdktf/provider-aws";

// Définition de la classe principale qui étend TerraformStack
export class HelloWorldTerra extends TerraformStack {
  constructor(scope: Construct, id: string) {
    super(scope, id);
    
    // Configuration du fournisseur AWS avec la région US West 2 (Oregon) et profil tfuser
    new AwsProvider(this, "aws", {
      region: "us-west-2",
      profile: "tfuser",
    });
    
    // Récupération de l'AMI Ubuntu la plus récente
    const ubuntuAmi = new DataAwsAmi(this, "ubuntu", {
      mostRecent: true,                    // Prendre la plus récente
      filter: [
        {
          name: "name",
          // Pattern pour Ubuntu 20.04 LTS Focal Fossa
          values: ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"],
        }
      ],
      owners: ["099720109477"],            // ID du compte Canonical (éditeur d'Ubuntu)
    });
    
    // Création d'une instance EC2
    const helloWorldInstance = new Instance(this, "helloworld", {
      ami: ubuntuAmi.id,                   // Utilisation de l'AMI Ubuntu récupérée
      instanceType: "t2.micro",           // Type d'instance (éligible free-tier)
      tags: {
        Name: "HelloWorld",                // Tag pour identifier l'instance
      },
    });
    
    // Sortie Terraform pour afficher l'ID de l'instance créée
    new TerraformOutput(this, "instance_id", {
      value: helloWorldInstance.id,
      description: "ID de l'instance EC2 HelloWorld",
    });
    
    // Sortie Terraform pour afficher l'adresse IP publique
    new TerraformOutput(this, "public_ip", {
      value: helloWorldInstance.publicIp,
      description: "Adresse IP publique de l'instance",
    });
    
    // Sortie Terraform pour afficher le DNS public
    new TerraformOutput(this, "public_dns", {
      value: helloWorldInstance.publicDns,
      description: "DNS public de l'instance",
    });
  }
}

// Création de l'application CDKTF
const app = new App();

// Instanciation de notre stack avec l'ID "helloworld-terra"
new HelloWorldTerra(app, "helloworld-terra");

// Génération du code Terraform JSON
app.synth();
```

équivalent de :

```coffeescript
provider "aws" {
  region = "us-west-2"
  profile = "tfuser"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  owners = ["099720109477"]
}

resource "aws_instance" "helloworld" {
  ami           = data.aws_ami.ubuntu.id 
  instance_type = "t2.micro"
  tags = {
    Name = "HelloWorld"
  }
}
```

## Les commandes principales de `terraform`

Documentation: 
* https://developer.hashicorp.com/terraform/cli

```bash
## Obtenir de l'aide sur la CLI 
$ terraform --help 
Usage: terraform [global options] <subcommand> [args]
The available commands for execution are listed below.
The primary workflow commands are given first, followed by
less common or more advanced commands.

Main commands:
  init          Prepare your working directory for other commands
  validate      Check whether the configuration is valid
  plan          Show changes required by the current configuration
  apply         Create or update infrastructure
  destroy       Destroy previously-created infrastructure

All other commands:
  console       Try Terraform expressions at an interactive command prompt
  fmt           Reformat your configuration in the standard style
  force-unlock  Release a stuck lock on the current workspace
  get           Install or upgrade remote Terraform modules
  graph         Generate a Graphviz graph of the steps in an operation
  import        Associate existing infrastructure with a Terraform resource
  login         Obtain and save credentials for a remote host
  logout        Remove locally-stored credentials for a remote host
  output        Show output values from your root module
  providers     Show the providers required for this configuration
  refresh       Update the state to match remote systems
  show          Show the current state or a saved plan
  state         Advanced state management
  taint         Mark a resource instance as not fully functional
  test          Experimental support for module integration testing
  untaint       Remove the 'tainted' state from a resource instance
  version       Show the current Terraform version
  workspace     Workspace management

Global options (use these before the subcommand, if any):
  -chdir=DIR    Switch to a different working directory before executing the
                given subcommand.
  -help         Show this help output, or the help for a specified subcommand.
  -version      An alias for the "version" subcommand.
  
## Obtenir de l'aide sur une commande 
$ terraform apply -h 
...
## Utiliser une commmande avec une option globale
$ terraform -chdir /opt/workplace apply
```

## Les domaines de commandes


#### Essentiels 
* Gérer l'espace de travail  
  * get 
  * init
* Gestion du cycle de vie des ressources
  * plan
  * apply
  * destroy
* Inspection / visualisation de l'infrastructure
  * show 
  * providers
  * graph
  * output
* Gestion de l'état de l'infrastructure  
  * state
* Test et réécriture 
  * console 
  * validate 
  * fmt

#### Avancés 

* Gestion des modules
  * get

* Authentification (Terraform Enterprise)
  * login
  * logout

* Gestion d'environnements 
  * wordspace 

* Import de ressources
  * import 
  
* Tests
  * test

---

## Commandes essentielles 

---

#### init

**La commande `init` encapsule tout ce qui est nécessaire pour rendre utilisable une recette d'infrastructure Terraform.**

* Initialisation du stockage de l'état afin de permettre de le stocker dans un backend (on y reviendra)
* Téléchargement des dépendances (modules et providers: idem on y reviendra)

```bash
$ ls -a1
.
..
main.tf

$ terraform init
Initializing the backend...

Initializing provider plugins...
- Finding latest version of hashicorp/aws...
- Installing hashicorp/aws v4.57.0...
- Installed hashicorp/aws v4.57.0 (signed by HashiCorp)

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.

$ ls -a1
.
..
main.tf
.terraform
.terraform.lock.hcl

```

On voit que la commande `init` crée deux éléments cachés 

* Le dossier `.terraform` contient les plugins / providers requis par la recette
* Le fichier `.terraform.lock.hcl` stocke la version des dépendances utilisées.   
  Ce fichier peut être ajouté au contrôle de version afin d'éviter que les versions déployées sont incompatibles.

---

#### plan

**La commande `plan` encapsule la logique de gestion du cycle de vie pour planifier les actions nécessaires.**

![](/134_cours_cli_terraform/images/terraform-plan-schema.png)

Elle est fondamentale dans le fonctionnement de Terraform.

Elle prend en compte l'état et les dépendances entre ressources à générer pour orchestrer les actions à entreprendre.

---

#### apply

**La commande `apply` exécute un plan, encapsulant par défaut un appel à `plan`.**

On peut aussi obtenir un plan sous forme de fichier et le passer à `apply`.

---

#### destroy

**La commande `destroy` génère un plan de destruction, encapsulant par défaut un appel à `plan`.**

C'est simplement un alias vers `terraform apply -destroy`

---

#### show 

**La commande `show` affiche le contenu d'un plan ou de l'état.**

```bash

$ terraform show -json terraform.tfstate
$ terraform plan -out plan.out && terraform show plan.out

```

---

#### providers

**La commande `providers` affiche les plugins / providers de la recette.**

```bash

$ terraform providers schema -json  | jq | less

```

---

#### graph

**La commande `graph` produit un graph au format DOT(.dot) de l'infrastructure.**

Elle permet de mieux comprendre / documenter des recettes.

```bash

$ terraform graph | dot -Tsvg > graph.svg

```

---

#### output

**La commande `output` extraie les valeurs qui ont été produites par la recette.**

Ces valeurs ne sont pas connues avant l'exécution et sont utiles pour communiquer entre différents modules. 

---

#### state

**La commande `state` permet d'afficher et d'interagir avec l'état de l'infrastructure.**

```bash

$ terraform state list

$ terraform state show <object>

```

---

#### console 

**La commande `console` permet d'exécuter des expressions en HCL au sein de l'état actuel de l'infrastructure.**

Cela permet de tester des appels de fonction avant de les tester dans le code.

---

#### validate 

**La commande `validate` permet de tester la validité programmatique de la recette, sans faire appel aux ressources.**

Elle est pratique pour s'assurer de la qualité du code.

---

#### fmt

**La commande `fmt` sert à rendre le style du code conforme aux normes.**

Elle fixe notamment les problèmes d'espaces et d'indentation pour uniformiser le style du code.

```bash
$ cat <<EOF | terraform fmt -
> foo =    "bar"
> l = [1,2,  3]
> EOF
foo = "bar"
l   = [1, 2, 3]

```

