---
title: TP partie 9 - Modules et gestion d'état avancée
weight: 12
---

Dans cette neuvième partie, nous allons apprendre à refactoriser notre infrastructure en modules Terraform et maîtriser les techniques avancées de gestion d'état : `terraform state mv` et `terraform import`.

## Problématiques de la refactorisation

### Le défi des changements de structure

Quand on refactorise du code Terraform existant, on se heurte à un problème fondamental : **Terraform suit les ressources par leur adresse dans l'état**. 

Prenons un exemple concret. Si vous avez une ressource :
```hcl
resource "aws_instance" "web_server" {
  # configuration...
}
```

Et que vous la déplacez dans un module :
```hcl
module "webserver" {
  source = "./modules/webserver"
  # ...
}
```

La ressource devient :
```
module.webserver.aws_instance.web_server[0]
```

**Problème** : Terraform ne reconnaît pas que c'est la même ressource ! Il va vouloir :
1. **Détruire** l'ancienne ressource `aws_instance.web_server`
2. **Créer** une nouvelle ressource `module.webserver.aws_instance.web_server[0]`

C'est exactement ce qu'on veut éviter en production !

## Solution 1 : terraform state mv

La commande `terraform state mv` permet de déplacer des ressources dans l'état sans les détruire/recréer.

### Préparation de la refactorisation

Commençons par déployer l'infrastructure de la partie 8 :

```bash
# Assurez-vous d'avoir un état déployé depuis part8
cd part8_count_loadbalancer
terraform workspace select default
terraform plan -var-file="multi-server.tfvars" -out=tfplan
terraform apply tfplan

# Listez les ressources actuelles
terraform state list
```

Vous devriez voir quelque chose comme :
```
aws_instance.web_server[0]
aws_instance.web_server[1]
aws_instance.web_server[2]
aws_lb.main[0]
aws_lb_listener.web[0]
aws_lb_target_group.web_servers[0]
aws_lb_target_group_attachment.web_servers[0]
aws_lb_target_group_attachment.web_servers[1]
aws_lb_target_group_attachment.web_servers[2]
aws_route53_record.web
aws_security_group.alb[0]
aws_security_group.web_servers
aws_subnet.public
aws_subnet.public_2
aws_vpc.main
...
```

### Copie de l'état pour la refactorisation

```bash
# Copiez l'infrastructure vers part9
cd ../part9_modules_state_management

# Copiez l'état depuis part8 
cp ../part8_count_loadbalancer/terraform.tfstate .
cp ../part8_count_loadbalancer/terraform.tfstate.backup .

# Initialisez part9 avec l'état existant
terraform init
```

### Création de la structure modulaire

Nos modules sont déjà créés dans `modules/`. Remplaçons maintenant les fichiers monolithiques par la configuration modulaire :

```bash
# Sauvegardez les anciens fichiers
mv main.tf main_old.tf
mv vpc.tf vpc_old.tf  
mv webserver.tf webserver_old.tf
mv loadbalancer.tf loadbalancer_old.tf
mv outputs.tf outputs_old.tf

# Utilisez les versions modulaires
mv main_modular.tf main.tf
mv outputs_modular.tf outputs.tf
```

### Test avant migration

```bash
# Voyons ce que Terraform pense de nos changements
terraform plan -var-file="multi-server.tfvars"
```

Terraform va montrer qu'il veut détruire toutes les ressources existantes et en créer de nouvelles. C'est exactement le problème qu'on veut résoudre !

## Migration avec terraform state mv

### Migration étape par étape

**1. Migration du module VPC :**

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

**2. Migration du module webserver :**

```bash
# Instances web
terraform state mv 'aws_instance.web_server[0]' 'module.webserver.aws_instance.web_server[0]'
terraform state mv 'aws_instance.web_server[1]' 'module.webserver.aws_instance.web_server[1]'
terraform state mv 'aws_instance.web_server[2]' 'module.webserver.aws_instance.web_server[2]'

# Data source AMI
terraform state mv data.aws_ami.custom_ubuntu module.webserver.data.aws_ami.custom_ubuntu
```

**3. Migration du module loadbalancer :**

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

```bash
# Vérifiez que toutes les ressources ont été déplacées
terraform state list

# Testez le plan - il ne devrait plus y avoir de destruction/création
terraform plan -var-file="multi-server.tfvars"
```

Si tout s'est bien passé, le plan devrait montrer "No changes" ou seulement des modifications mineures !

## Solution 2 : terraform import

Parfois, vous avez des ressources AWS créées manuellement ou par d'autres outils que vous voulez intégrer à Terraform. C'est là qu'intervient `terraform import`.

### Exemple pratique : Importation d'un enregistrement Route53

Supposons que vous ayez créé manuellement un enregistrement DNS pour pointer vers votre load balancer, et que vous vouliez maintenant le gérer avec Terraform.

**1. Création manuelle d'une ressource DNS :**

```bash
# Depuis le projet Route53 exemple
cd ../route53_example_for_import

# Récupérez l'IP de votre load balancer
cd ../part9_modules_state_management
ALB_DNS=$(terraform output -raw load_balancer_dns)
echo "ALB DNS: $ALB_DNS"

# Résolvez l'IP (pour l'exemple, on utilisera une IP fictive)
cd ../route53_example_for_import
```

**2. Créez la zone et l'enregistrement manuellement :**

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

**3. Importation dans Terraform :**

```bash
# Importez l'enregistrement existant
terraform import aws_route53_record.web ${ZONE_ID}_web.example-terraform-demo.com_A

# Vérifiez que l'import a fonctionné
terraform plan
```

### Intégration avec l'infrastructure principale

Maintenant, ajoutons la gestion DNS à notre infrastructure principale :

**1. Ajout du module DNS à part9 :**

```bash
cd ../part9_modules_state_management

# Ajoutez la configuration DNS au main.tf
```

Ajoutez cette section à `main.tf` :

```hcl
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

**2. Import de l'enregistrement existant :**

```bash
# Si vous voulez importer l'enregistrement DNS créé précédemment
# terraform import 'aws_route53_record.web[0]' ${ZONE_ID}_web.example-terraform-demo.com_A
```

## Bonnes pratiques pour la gestion d'état

### Avant toute refactorisation

**1. Sauvegardez toujours l'état :**

```bash
# Sauvegarde manuelle
cp terraform.tfstate terraform.tfstate.backup-$(date +%Y%m%d-%H%M%S)

# Ou exportez l'état
terraform show -json > state-backup-$(date +%Y%m%d-%H%M%S).json
```

**2. Testez sur un workspace séparé :**

```bash
# Créez un workspace de test
terraform workspace new refactoring-test
terraform apply -var-file="multi-server.tfvars"

# Effectuez la migration sur ce workspace
# Si ça marche, appliquez sur le workspace principal
```

**3. Planifiez la migration :**

```bash
# Listez toutes les ressources
terraform state list > resources-before.txt

# Après migration, comparez
terraform state list > resources-after.txt
diff resources-before.txt resources-after.txt
```

### Commandes utiles pour la gestion d'état

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
terraform state mv aws_instance.web aws_instance.module.webserver.aws_instance.web
```

**Import de ressources existantes :**
```bash
terraform import module.webserver.aws_instance.web[0] i-1234567890abcdef0
```

## Validation finale

Une fois la migration terminée :

```bash
# Plan final - devrait montrer "No changes"
terraform plan -var-file="multi-server.tfvars"

# Test de l'application
curl $(terraform output -raw web_url)

# Vérification des modules
terraform validate
```

## Conclusion

Cette partie vous a montré comment :

1. **Refactoriser** une infrastructure monolithique en modules sans interruption de service
2. **Utiliser terraform state mv** pour déplacer des ressources dans l'état
3. **Utiliser terraform import** pour intégrer des ressources existantes
4. **Appliquer les bonnes pratiques** de gestion d'état

Points clés à retenir :
- Toujours sauvegarder l'état avant une refactorisation
- Tester sur un workspace séparé d'abord
- Utiliser `terraform state mv` pour éviter les destructions/recréations
- Utiliser `terraform import` pour intégrer des ressources existantes
- La modularisation améliore la réutilisabilité et la maintenance

Ces techniques sont essentielles pour maintenir et faire évoluer des infrastructures Terraform en production de manière sûre et contrôlée.