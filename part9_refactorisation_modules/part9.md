---
title: TP partie 9 - Modules et gestion d'état avancée
weight: 12
---

Dans cette neuvième partie, nous allons apprendre à refactoriser notre infrastructure en modules Terraform et maîtriser les techniques avancées de gestion d'état : `terraform state mv` et `terraform import`.

## Problématiques de la refactorisation

Quand on refactorise du code Terraform existant, on se heurte à un problème fondamental : **Terraform suit les ressources par leur adresse dans l'état**. Si vous avez une ressource déclarée directement puis que vous la déplacez dans un module, Terraform ne reconnaît pas que c'est la même ressource ! Il va vouloir détruire l'ancienne et créer une nouvelle, ce qui peut entraîner une interruption de service.

Prenons un exemple concret. Une ressource déclarée directement :
```coffee
resource "aws_instance" "web_server" {
  # configuration...
}
```

Devient, après refactorisation en module :
```coffee
module "webserver" {
  source = "./modules/webserver"
  # ...
}
```

La ressource prend alors l'adresse `module.webserver.aws_instance.web_server[0]` dans l'état. C'est exactement ce qu'on veut éviter en production : une destruction/recréation non planifiée.

## terraform state mv

La commande `terraform state mv` permet de déplacer des ressources dans l'état sans les détruire/recréer.

### Préparation de la refactorisation

Pour cette démonstration, nous allons partir d'un déploiement existant de la partie 8. Commençons par nous assurer que l'infrastructure est déployée :

```bash
# Assurez-vous d'avoir un état déployé depuis part8
cd part8_count_loadbalancer
terraform workspace select default
terraform plan -var-file="multi-server.tfvars" -out=tfplan
terraform apply tfplan

# Listez les ressources actuelles
terraform state list
```

Cette commande vous montrera toutes les ressources déployées, organisées de manière monolithique. Vous devriez voir des ressources comme `aws_instance.web_server[0]`, `aws_lb.main[0]`, `aws_vpc.main`, etc.

### Préparation de la refactorisation

Nous allons effectuer la refactorisation directement dans le projet part8. Cette approche est plus réaliste car elle utilise le backend S3 configuré :

```bash
# Travaillons directement dans part8 pour commencer
cd part8_count_loadbalancer

# Créons d'abord une sauvegarde de sécurité
terraform state pull > terraform.tfstate.backup-$(date +%Y%m%d-%H%M%S)

# Copions les modules depuis part9
cp -r ../part9_refactorisation_modules/modules .

# Remplaçons directement les fichiers par leurs versions modulaires
cp ../part9_refactorisation_modules/main.tf .
cp ../part9_refactorisation_modules/outputs.tf .

# Supprimons les anciens fichiers maintenant obsolètes
rm vpc.tf webserver.tf loadbalancer.tf
```

### Test avant migration

Nos modules sont déjà créés dans `modules/` et notre configuration utilise déjà ces modules. Voyons ce que Terraform pense de nos changements :

```bash
# Voyons ce que Terraform pense de nos changements
terraform plan -var-file="multi-server.tfvars"
```

Terraform va montrer qu'il veut détruire toutes les ressources existantes et en créer de nouvelles. C'est exactement le problème qu'on veut résoudre ! La solution est d'utiliser `terraform state mv` pour déplacer les ressources vers leur nouvelle adresse dans les modules.

## Migration avec terraform state mv

Nous allons maintenant migrer chaque ressource de son ancienne adresse vers sa nouvelle adresse dans les modules. Cette opération doit être effectuée avec précaution et il est fortement recommandé de sauvegarder l'état avant de commencer.

### Migration étape par étape

La migration s'effectue en trois étapes principales : le module VPC, le module webserver, et le module loadbalancer.

**Migration du module VPC :**

```bash
# VPC principal
terraform state mv aws_vpc.main module.vpc.aws_vpc.main

# Internet Gateway
terraform state mv aws_internet_gateway.main module.vpc.aws_internet_gateway.main

# Subnets
terraform state mv aws_subnet.public module.vpc.aws_subnet.public
terraform state mv aws_subnet.public_2 module.vpc.aws_subnet.public_2

# Route table et associations
terraform state mv aws_route_table.public module.vpc.aws_route_table.public
terraform state mv aws_route_table_association.public module.vpc.aws_route_table_association.public
terraform state mv aws_route_table_association.public_2 module.vpc.aws_route_table_association.public_2

# Security groups
terraform state mv aws_security_group.web_servers module.vpc.aws_security_group.web_servers
terraform state mv 'aws_security_group.alb[0]' 'module.vpc.aws_security_group.alb[0]'

# Data source (sera recréé automatiquement)
terraform state mv data.aws_availability_zones.available module.vpc.data.aws_availability_zones.available
```

**Migration du module webserver :**

```bash
# Instances web
terraform state mv 'aws_instance.web_server[0]' 'module.webserver.aws_instance.web_server[0]'
terraform state mv 'aws_instance.web_server[1]' 'module.webserver.aws_instance.web_server[1]'
terraform state mv 'aws_instance.web_server[2]' 'module.webserver.aws_instance.web_server[2]'

# Data source AMI
terraform state mv data.aws_ami.custom_ubuntu module.webserver.data.aws_ami.custom_ubuntu
```

**Migration du module loadbalancer :**

```bash
# Load balancer
terraform state mv 'aws_lb.main[0]' 'module.loadbalancer.aws_lb.main[0]'

# Target group
terraform state mv 'aws_lb_target_group.web_servers[0]' 'module.loadbalancer.aws_lb_target_group.web_servers[0]'

# Target group attachments
terraform state mv 'aws_lb_target_group_attachment.web_servers[0]' 'module.loadbalancer.aws_lb_target_group_attachment.web_servers[0]'
terraform state mv 'aws_lb_target_group_attachment.web_servers[1]' 'module.loadbalancer.aws_lb_target_group_attachment.web_servers[1]'
terraform state mv 'aws_lb_target_group_attachment.web_servers[2]' 'module.loadbalancer.aws_lb_target_group_attachment.web_servers[2]'

# Listener
terraform state mv 'aws_lb_listener.web[0]' 'module.loadbalancer.aws_lb_listener.web[0]'
```

### Vérification de la migration

Une fois toutes les ressources migrées, vérifiez que l'opération s'est bien déroulée :

```bash
# Vérifiez que toutes les ressources ont été déplacées
terraform state list

# Testez le plan - il ne devrait plus y avoir de destruction/création
terraform plan -var-file="multi-server.tfvars"
```

Si tout s'est bien passé, le plan devrait montrer "No changes" ou seulement des modifications mineures ! Cela confirme que nos ressources sont maintenant correctement organisées en modules sans risque de destruction.

### Finalisation de la refactorisation

Une fois la migration terminée et validée, nous avons maintenant une infrastructure modulaire fonctionnelle. Si vous souhaitez garder le projet part8 intact, vous pouvez créer une copie finale :

```bash
# Copions le projet refactorisé vers part9
cd ..
cp -r part8_count_loadbalancer part9_refactorisation_modules_final

# Nettoyons le répertoire part9 final
cd part9_refactorisation_modules_final
rm -f part8.md architecture.mmd architecture_part8.png alb-components.mmd alb-components.png

# Ajoutons la documentation part9
cp ../part9_refactorisation_modules/part9.md .
```

## terraform import

Parfois, vous avez des ressources AWS créées manuellement ou par d'autres outils que vous voulez intégrer à Terraform. C'est là qu'intervient `terraform import`.

### Exemple pratique : Importation d'un enregistrement Route53

Supposons que vous ayez créé manuellement un enregistrement DNS pour pointer vers votre load balancer, et que vous vouliez maintenant le gérer avec Terraform. Nous allons utiliser le projet d'exemple Route53 pour démontrer cette fonctionnalité.

**Création manuelle d'une ressource DNS :**

```bash
# Depuis le projet Route53 exemple
cd ../route53_example_for_import

# Récupérez l'IP de votre load balancer
cd ../part9_refactorisation_modules
ALB_DNS=$(terraform output -raw load_balancer_dns)
echo "ALB DNS: $ALB_DNS"

# Résolvez l'IP (pour l'exemple, on utilisera une IP fictive)
cd ../route53_example_for_import
```

**Création de la zone et de l'enregistrement manuellement :**

```bash
# Créez d'abord la zone DNS
terraform apply -target=aws_route53_zone.main

# Notez l'ID de la zone
ZONE_ID=$(terraform output -raw zone_id)
echo "Zone ID: $ZONE_ID"

# Créez manuellement un enregistrement DNS via AWS CLI
aws route53 change-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "web.example-terraform-demo.com",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value": "1.2.3.4"}]
      }
    }]
  }' \
  --profile <awsprofile-votreprenom>
```

**Importation dans Terraform :**

```bash
# Importez l'enregistrement existant
terraform import aws_route53_record.web ${ZONE_ID}_web.example-terraform-demo.com_A

# Vérifiez que l'import a fonctionné
terraform plan
```

Cette opération intègre une ressource existante dans l'état Terraform, permettant de la gérer ensuite via les fichiers de configuration.

### Intégration avec l'infrastructure principale

Si vous souhaitez intégrer la gestion DNS directement dans votre infrastructure principale, vous pouvez ajouter une configuration Route53 optionnelle. Voici comment procéder :

```coffee
# Module DNS (si on veut gérer Route53)
# resource "aws_route53_record" "web" {
#   count   = var.instance_count > 1 ? 1 : 0
#   zone_id = var.route53_zone_id
#   name    = "web.${var.domain_name}"
#   type    = "CNAME"
#   ttl     = 300
#   records = [module.loadbalancer.load_balancer_dns]
# }
```

Cette configuration permettrait d'importer l'enregistrement DNS créé précédemment :

```bash
# Si vous voulez importer l'enregistrement DNS créé précédemment
# terraform import 'aws_route53_record.web[0]' ${ZONE_ID}_web.example-terraform-demo.com_A
```

## Bonnes pratiques pour la gestion d'état

Avant toute refactorisation ou manipulation d'état, il est essentiel de suivre certaines bonnes pratiques pour éviter toute perte de données ou interruption de service.

### Avant toute refactorisation

**Sauvegardez toujours l'état :**

```bash
# Sauvegarde manuelle
cp terraform.tfstate terraform.tfstate.backup-$(date +%Y%m%d-%H%M%S)

# Ou exportez l'état
terraform show -json > state-backup-$(date +%Y%m%d-%H%M%S).json
```

**Testez sur un workspace séparé :**

```bash
# Créez un workspace de test
terraform workspace new refactoring-test
terraform apply -var-file="multi-server.tfvars"

# Effectuez la migration sur ce workspace
# Si ça marche, appliquez sur le workspace principal
```

**Planifiez la migration :**

```bash
# Listez toutes les ressources
terraform state list > resources-before.txt

# Après migration, comparez
terraform state list > resources-after.txt
diff resources-before.txt resources-after.txt
```

### Commandes utiles pour la gestion d'état

Voici les commandes principales pour manipuler l'état Terraform :

```bash
# Lister toutes les ressources
terraform state list

# Voir les détails d'une ressource
terraform state show aws_instance.web_server[0]

# Retirer une ressource de l'état (sans la détruire)
terraform state rm aws_instance.web_server[0]

# Importer une ressource existante
terraform import aws_instance.web_server[0] i-1234567890abcdef0

# Déplacer une ressource
terraform state mv aws_instance.web_server[0] module.webserver.aws_instance.web_server[0]

# Remplacer un provider
terraform state replace-provider hashicorp/aws registry.terraform.io/hashicorp/aws
```

### Cas d'usage courants

**Renommage de ressources :**
```bash
terraform state mv aws_instance.old_name aws_instance.new_name
```

**Déplacement vers un module :**
```bash
terraform state mv aws_instance.web module.webserver.aws_instance.web
```

**Import de ressources existantes :**
```bash
terraform import module.webserver.aws_instance.web[0] i-1234567890abcdef0
```

## Validation finale

Une fois la migration terminée, il est important de valider que tout fonctionne correctement :

```bash
# Plan final - devrait montrer "No changes"
terraform plan -var-file="multi-server.tfvars"

# Test de l'application
curl $(terraform output -raw web_url)

# Vérification des modules
terraform validate
```

## Conclusion

Cette partie vous a montré comment refactoriser une infrastructure monolithique en modules sans interruption de service. Nous avons exploré deux techniques essentielles : `terraform state mv` pour déplacer des ressources dans l'état et `terraform import` pour intégrer des ressources existantes.

Les points clés à retenir sont la nécessité de toujours sauvegarder l'état avant une refactorisation, de tester sur un workspace séparé, et d'utiliser ces commandes pour éviter les destructions/recréations non désirées. La modularisation améliore considérablement la réutilisabilité et la maintenance des infrastructures Terraform.

Ces techniques sont essentielles pour maintenir et faire évoluer des infrastructures Terraform en production de manière sûre et contrôlée.