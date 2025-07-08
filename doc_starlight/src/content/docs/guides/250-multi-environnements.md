---
title: "TP partie 10 - Déploiement Multi-Environnements avec Terraform"
description: "Guide TP partie 10 - Déploiement Multi-Environnements avec Terraform"
sidebar:
  order: 250
---


Dans cette dixième partie, nous allons apprendre à structurer et déployer une infrastructure Terraform pour plusieurs environnements (développement, staging, production). Cette partie se concentre sur l'organisation avancée des projets et les bonnes pratiques de déploiement multi-environnements.

## Les enjeux du multi-environnement

### Pourquoi plusieurs environnements ?

Le déploiement multi-environnements permet de :
- Tester les changements sans impacter la production
- Valider les configurations dans un environnement similaire
- Réduire les risques lors des déploiements
- Permettre le développement parallèle

### Les défis à relever

1. **Isolation des environnements** : Éviter les interférences entre environnements
2. **Gestion des configurations** : Maintenir des paramètres différents par environnement
3. **Cohérence du code** : Utiliser le même code pour tous les environnements
4. **Sécurité** : Protéger l'environnement de production

## Stratégie de gestion multi-environnements : Approche par Répertoires

Pour ce TP, nous utilisons l'approche par répertoires séparés, qui est la méthode la plus robuste et claire pour gérer plusieurs environnements.

**Avantages de l'approche par répertoires :**
- **Isolation complète** : Chaque environnement a son propre état Terraform
- **Sécurité renforcée** : Impossible de modifier accidentellement le mauvais environnement
- **Flexibilité** : Configurations différentes par environnement
- **CI/CD friendly** : Pipelines simples à mettre en place

**Structure à construire :**

```
250_multi_environnements/
├── modules/
│   ├── vpc/
│   ├── webserver/
│   └── loadbalancer/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars
│   ├── staging/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars
├── scripts/
│   ├── deploy.sh
│   └── validate.sh
└── global/
    └── backend-config.tf
```

**Pourquoi éviter les workspaces ?**
- **Risques d'erreur** : Facile de se tromper d'environnement
- **État partagé** : Tous les workspaces utilisent le même backend
- **Complexité** : Gestion des variables et configurations plus difficile
- **Manque de flexibilité** : Difficile d'avoir des configurations très différentes

## Mise en place de la structure multi-environnements

### Étape 1 : Copier la structure modulaire existante

Partez du code de la partie 9 (copiez le dossier ou commitez les changements). Dans le dossier part10, nous allons créer une architecture multi-environnements basée sur les modules existants :

```bash
# Copier la structure modulaire depuis la Part 9
cp -r ../240_refactorisation_modules/modules .

# Créer la structure multi-environnement
mkdir -p environments/{dev,staging,prod}
mkdir -p global scripts
```

### Étape 2 : Copier les fichiers de base vers tous les environnements

Nous allons partir des fichiers de la Part 9 et les adapter pour chaque environnement :

```bash
# Copier les fichiers pour l'environnement dev
cp ../240_refactorisation_modules/main.tf environments/dev/
cp ../240_refactorisation_modules/variables.tf environments/dev/
cp ../240_refactorisation_modules/outputs.tf environments/dev/

# Copier les fichiers pour l'environnement staging
cp ../240_refactorisation_modules/main.tf environments/staging/
cp ../240_refactorisation_modules/variables.tf environments/staging/
cp ../240_refactorisation_modules/outputs.tf environments/staging/

# Copier les fichiers pour l'environnement prod
cp ../240_refactorisation_modules/main.tf environments/prod/
cp ../240_refactorisation_modules/variables.tf environments/prod/
cp ../240_refactorisation_modules/outputs.tf environments/prod/
```

### Étape 3 : Vérification de la configuration du backend S3

Chaque fichier `environments/*/main.tf` contient déjà la configuration minimale du backend :

```coffee
terraform {
  # ... providers ...
  
  # Backend configuré dynamiquement
  backend "s3" {}
}
```

Cette configuration vide `backend "s3" {}` est intentionnelle. Elle indique à Terraform d'utiliser S3 comme backend, mais les paramètres spécifiques (bucket, key, region, profile) seront fournis lors de l'initialisation via la commande `terraform init -backend-config`.

**Pourquoi cette approche ?**
- Chaque environnement doit avoir son propre état dans S3
- La clé (path) dans S3 doit être différente pour chaque environnement  
- Les paramètres du backend sont passés dynamiquement pour éviter toute confusion

### Étape 4 : Adapter les fichiers main.tf pour chaque environnement

Pour chaque environnement, nous devons modifier le fichier `main.tf` pour :
1. Utiliser le backend S3 sans configuration statique
2. Ajuster les paramètres workspace dans les modules

**Pourquoi fixer le workspace en dur ?**

Dans l'approche multi-environnements par dossiers (au lieu d'utiliser les workspaces Terraform), nous fixons le nom du workspace en dur dans chaque environnement pour plusieurs raisons :

- **Clarté** : Le nom de l'environnement est explicite dans le code, pas dépendant d'un état externe
- **Isolation** : Impossible de déployer accidentellement dans le mauvais environnement
- **Simplicité** : Pas besoin de changer de workspace avant chaque déploiement
- **Cohérence** : Les tags et noms de ressources correspondent toujours à l'environnement réel

Cette approche élimine le risque d'erreur humaine où quelqu'un oublierait de changer de workspace avant un déploiement.

#### Environnement dev

Éditez `environments/dev/main.tf` et modifiez :

Le fichier main.tf est déjà correctement configuré avec :
- `backend "s3" {}` pour permettre la configuration dynamique
- `workspace = "dev"` passé directement aux modules (pas de variable, juste la valeur en dur)

Vérifiez que les modules reçoivent bien le nom de l'environnement :
```coffee
# Module VPC
module "vpc" {
  source = "../../modules/vpc"
  # ... autres variables ...
  workspace = "dev"  # Valeur fixe pour l'environnement dev
}

# Module Webserver
module "webserver" {
  source = "../../modules/webserver"
  # ... autres variables ...
  workspace = "dev"  # Valeur fixe pour l'environnement dev
}

# Module Load Balancer
module "loadbalancer" {
  source = "../../modules/loadbalancer"
  # ... autres variables ...
  workspace = "dev"  # Valeur fixe pour l'environnement dev
}
```

#### Environnement staging

Éditez `environments/staging/main.tf` et effectuez les mêmes modifications que pour dev, mais avec :

```coffee
# Dans tous les modules :
workspace = "staging"
```

#### Environnement prod

Éditez `environments/prod/main.tf` et effectuez les mêmes modifications que pour dev, mais avec :

```coffee
# Dans tous les modules :
workspace = "prod"
```

### Étape 5 : Créer les fichiers terraform.tfvars spécifiques

Au lieu de modifier les variables.tf, nous utilisons des fichiers .tfvars spécifiques à chaque environnement :

```bash
# Environnement dev
cat > environments/dev/terraform.tfvars << 'EOF'
instance_count = 1
instance_type  = "t2.micro"
feature_name   = "dev"
EOF

# Environnement staging
cat > environments/staging/terraform.tfvars << 'EOF'
instance_count = 2
instance_type  = "t2.small"
feature_name   = "staging"
EOF

# Environnement prod
cat > environments/prod/terraform.tfvars << 'EOF'
instance_count = 3
instance_type  = "t2.small"
feature_name   = "prod"
EOF
```

### Étape 6 : Créer le script de déploiement

Créez un script automatisé pour déployer sur tous les environnements :

```bash
# Créer le script de déploiement
cat > scripts/deploy.sh << 'EOF'
#!/bin/bash
set -e

ENVIRONMENT=$1

if [ -z "$ENVIRONMENT" ]; then
    echo "Usage: ./deploy.sh [dev|staging|prod]"
    exit 1
fi

# Validation de l'environnement
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo "Error: Environment must be dev, staging, or prod"
    exit 1
fi

# Protection pour la production
if [ "$ENVIRONMENT" == "prod" ]; then
    echo "⚠️  WARNING: You are about to deploy to PRODUCTION!"
    read -p "Are you sure? Type 'yes' to continue: " confirmation
    if [ "$confirmation" != "yes" ]; then
        echo "Deployment cancelled."
        exit 0
    fi
fi

cd "environments/$ENVIRONMENT"

# Initialisation avec le backend spécifique
# Les autres paramètres (bucket, region, profile) sont définis dans main.tf
terraform init \
    -backend-config="bucket=terraform-state-<YOUR-BUCKET-NAME>" \
    -backend-config="key=tp-fil-rouge-${ENVIRONMENT}/terraform.tfstate" \
    -backend-config="region=eu-west-3" \
    -backend-config="profile=default"

# Plan
echo "📋 Creating execution plan for $ENVIRONMENT..."
terraform plan -out=tfplan

# Apply avec confirmation
echo "🚀 Applying changes to $ENVIRONMENT..."
terraform apply tfplan

echo "✅ Deployment to $ENVIRONMENT completed!"
EOF

# Rendre le script exécutable
chmod +x scripts/deploy.sh
```

### Étape 7 : Créer le script de validation

Créez également un script pour valider tous les environnements :

```bash
# Créer le script de validation
cat > scripts/validate.sh << 'EOF'
#!/bin/bash
set -e

echo "🔍 Validating Terraform configurations..."

for env in dev staging prod; do
    echo "Checking $env environment..."
    cd "environments/$env"
    
    # Format check
    terraform fmt -check
    
    # Validation
    terraform validate
    
    cd ../..
done

echo "✅ All environments validated successfully!"
EOF

# Rendre le script exécutable
chmod +x scripts/validate.sh
```

### Vérification de la structure

Vérifiez que tous les fichiers ont été correctement copiés et adaptés :

```bash
# Vérifier la structure créée
tree environments/

# Valider la configuration de tous les environnements
./scripts/validate.sh

# Tester l'initialisation pour chaque environnement
for env in dev staging prod; do
    echo "Testing $env environment..."
    cd environments/$env
    terraform init -backend-config="key=tp-fil-rouge-${env}/terraform.tfstate"
    terraform plan
    cd ../..
done
```

**Résultat attendu** : 
- La structure doit montrer 3 environnements avec les mêmes fichiers (main.tf, variables.tf, outputs.tf, terraform.tfvars)
- La validation doit passer pour tous les environnements
- L'initialisation et le plan doivent fonctionner pour dev, staging et prod

Cette vérification confirme que la structure multi-environnements est correctement configurée et que chaque environnement est isolé avec ses propres paramètres.

## Résumé de l'approche multi-environnements

### Architecture choisie

Nous avons implémenté une approche basée sur des **dossiers séparés** plutôt que sur les workspaces Terraform :

```
environments/
├── dev/       # Environnement de développement
├── staging/   # Environnement de staging  
└── prod/      # Environnement de production
```

### Points clés de l'implémentation

1. **Backend S3 dynamique** : Chaque environnement a `backend "s3" {}` dans son main.tf. La configuration complète est passée lors de l'init.

2. **Workspace fixé en dur** : Dans chaque main.tf, on passe directement `workspace = "dev"`, `workspace = "staging"` ou `workspace = "prod"` aux modules (pas de variable).

3. **Isolation complète** : Chaque environnement a :
   - Son propre état Terraform dans S3 (`tp-fil-rouge-dev/terraform.tfstate`, etc.)
   - Ses propres valeurs dans `terraform.tfvars`
   - Son propre dossier isolé

4. **Scripts d'automatisation** :
   - `deploy.sh` : Gère l'initialisation du backend et le déploiement
   - `validate.sh` : Valide tous les environnements

## Déploiement et test des trois environnements

### Déploiement de l'environnement de développement

Commencez par déployer l'environnement de développement :

```bash
# Déployer l'environnement de développement
./scripts/deploy.sh dev
```

### Validation du déploiement dev

Vérifiez que l'infrastructure est correctement déployée :

```bash
# Tester l'accès au load balancer
cd environments/dev
curl $(terraform output -raw web_url)

# Vérifier les outputs
terraform output
cd ../..
```

**Résultat attendu** : 
- 1 instance EC2 t2.micro déployée
- Load balancer fonctionnel
- Page web accessible

### Déploiement staging

Une fois le développement validé, déployez staging avec 2 instances :

```bash
# Déploiement staging
./scripts/deploy.sh staging

# Validation staging
cd environments/staging
terraform output
curl $(terraform output -raw web_url)
cd ../..
```

**Résultat attendu** : 
- 2 instances EC2 t2.small déployées  
- Load balancer avec plus de capacité

### Déploiement production

Enfin, déployez la production avec 3 instances :

```bash
# Déploiement production (avec confirmation)
./scripts/deploy.sh prod

# Validation production
cd environments/prod  
terraform output
curl $(terraform output -raw web_url)
cd ../..
```

**Résultat attendu** :
- 3 instances EC2 t2.medium déployées
- Infrastructure de production complète
- Confirmation manuelle requise avant déploiement


### Exemple de pipeline CI/CD

Exemple de configuration GitLab CI :

```yaml
# .gitlab-ci.yml - Pipeline CI/CD pour multi-environnements Terraform

# Définition des étapes du pipeline
stages:
  - validate  # Validation et formatage du code
  - plan      # Création des plans d'exécution
  - deploy    # Déploiement sur les environnements

# Variables globales du pipeline
variables:
  TF_ROOT: ${CI_PROJECT_DIR}/environments  # Chemin vers les environnements
  TF_IN_AUTOMATION: "true"                 # Indique à Terraform qu'il est en mode automatisé

# Template de base réutilisé par tous les jobs Terraform
.terraform-base:
  image: hashicorp/terraform:1.5  # Image Docker officielle Terraform
  before_script:
    - cd ${TF_ROOT}/${ENVIRONMENT}  # Se placer dans le bon environnement
    # Initialiser avec la clé spécifique à l'environnement
    - terraform init -backend-config="key=${ENVIRONMENT}/terraform.tfstate"

# Job de validation : vérifie le formatage et la syntaxe
validate:
  extends: .terraform-base
  stage: validate
  script:
    - terraform fmt -check  # Vérifier le formatage du code
    - terraform validate    # Valider la syntaxe Terraform
  # Exécution en parallèle pour tous les environnements
  parallel:
    matrix:
      - ENVIRONMENT: [dev, staging, prod]

# Job de planification : créer les plans d'exécution
plan:
  extends: .terraform-base
  stage: plan
  script:
    - terraform plan -out=plan.tfplan  # Créer le plan d'exécution
  # Sauvegarder le plan comme artefact pour l'étape suivante
  artifacts:
    paths:
      - ${TF_ROOT}/${ENVIRONMENT}/plan.tfplan
    expire_in: 7 days  # Les plans expirent après 7 jours
  # Exécution en parallèle pour tous les environnements
  parallel:
    matrix:
      - ENVIRONMENT: [dev, staging, prod]

# Déploiement automatique sur dev (branche develop)
deploy:dev:
  extends: .terraform-base
  stage: deploy
  environment:
    name: dev  # Nom de l'environnement GitLab
  variables:
    ENVIRONMENT: dev
  script:
    - terraform apply plan.tfplan  # Appliquer le plan sauvegardé
  dependencies:
    - plan  # Dépend du job plan pour récupérer l'artefact
  only:
    - develop  # Se déclenche uniquement sur la branche develop

# Déploiement automatique sur staging (branche main)
deploy:staging:
  extends: .terraform-base
  stage: deploy
  environment:
    name: staging  # Nom de l'environnement GitLab
  variables:
    ENVIRONMENT: staging
  script:
    - terraform apply plan.tfplan  # Appliquer le plan sauvegardé
  dependencies:
    - plan  # Dépend du job plan pour récupérer l'artefact
  only:
    - main  # Se déclenche uniquement sur la branche main

# Déploiement manuel sur production (tags uniquement)
deploy:prod:
  extends: .terraform-base
  stage: deploy
  environment:
    name: production  # Nom de l'environnement GitLab
  variables:
    ENVIRONMENT: prod
  script:
    - terraform apply plan.tfplan  # Appliquer le plan sauvegardé
  dependencies:
    - plan  # Dépend du job plan pour récupérer l'artefact
  when: manual  # Déclenchement manuel obligatoire pour la production
  only:
    - tags  # Se déclenche uniquement sur les tags (releases)
```

## Ressources supplémentaires

- [Terraform State Management](https://www.terraform.io/docs/state/index.html)
- [AWS Well-Architected Framework - Reliability Pillar](https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/welcome.html)
- [HashiCorp Best Practices for Multi-Environment](https://learn.hashicorp.com/tutorials/terraform/organize-configuration)
