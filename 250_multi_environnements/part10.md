---
title: TP partie 10 -  Déploiement Multi-Environnements avec Terraform
weight: 12
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
- **Clarté** : Structure explicite et facile à comprendre
- **Flexibilité** : Configurations différentes par environnement
- **CI/CD friendly** : Pipelines simples à mettre en place

**Structure a construire :**

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

### Étape 3 : Adapter le backend.tf pour la structure multi-environnements

Créons un fichier global pour la configuration backend :

```bash
# Déplacer et adapter la configuration backend
cp ../240_refactorisation_modules/backend.tf global/backend-config.tf
```

Éditez `global/backend-config.tf` pour l'adapter aux multiples environnements (la clé sera spécifiée dynamiquement).

### Étape 4 : Adapter les fichiers main.tf pour chaque environnement

Pour chaque environnement, nous devons modifier le fichier `main.tf` pour :
1. Utiliser le backend S3 sans configuration statique
2. Ajuster les paramètres workspace dans les modules

#### Environnement dev

Éditez `environments/dev/main.tf` et modifiez :

1. La section backend S3 (qui contenait des paramètres spécifiques) :
```coffee
# Remplacer ceci :
backend "s3" {
  bucket         = "terraform-state-<YOUR-BUCKET-NAME>"
  key            = "tp-fil-rouge-dev/terraform.tfstate"
  region         = "eu-west-3"
  profile        = "<awsprofile-votreprenom>"
  encrypt        = true
  use_lockfile   = true
  dynamodb_table = "terraform-state-lock"
}

# Par ceci :
backend "s3" {}
```

2. Les références workspace dans les modules :
```coffee
# Dans module "vpc", remplacer :
workspace = terraform.workspace

# Par :
workspace = "dev"

# Faire de même pour les modules "webserver" et "loadbalancer"
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
instance_type  = "t2.medium"
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
terraform init \
    -backend-config="key=tp-fil-rouge-${ENVIRONMENT}/terraform.tfstate"

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

## Bonnes pratiques

### 1. Isolation des états

Chaque environnement doit avoir son propre état Terraform :

```coffee
# backend-dev.hcl
key = "dev/terraform.tfstate"

# backend-staging.hcl
key = "staging/terraform.tfstate"

# backend-prod.hcl
key = "prod/terraform.tfstate"
```

### 2. Contrôle d'accès

Implémentez des politiques IAM différenciées :

```coffee
# IAM policy pour dev
resource "aws_iam_policy" "terraform_dev" {
  name = "terraform-dev-policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["*"]
        Resource = ["*"]
        Condition = {
          StringEquals = {
            "aws:RequestedRegion": var.aws_region
          }
        }
      }
    ]
  })
}

# IAM policy pour prod (plus restrictive)
resource "aws_iam_policy" "terraform_prod" {
  name = "terraform-prod-policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:CreateTags",
          "ec2:RunInstances",
          "ec2:TerminateInstances"
        ]
        Resource = ["*"]
        Condition = {
          StringEquals = {
            "ec2:InstanceType": ["t2.medium", "t2.large"]
          }
        }
      }
    ]
  })
}
```

### 3. Validation et tests

Créez `scripts/validate.sh` :

```bash
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
    
    # Linting avec tflint si disponible
    if command -v tflint &> /dev/null; then
        tflint
    fi
    
    cd ../..
done

echo "✅ All environments validated successfully!"
```

### 4. Pipeline CI/CD

Exemple de configuration GitLab CI :

```yaml
# .gitlab-ci.yml
stages:
  - validate
  - plan
  - deploy

variables:
  TF_ROOT: ${CI_PROJECT_DIR}/environments
  TF_IN_AUTOMATION: "true"

.terraform-base:
  image: hashicorp/terraform:1.5
  before_script:
    - cd ${TF_ROOT}/${ENVIRONMENT}
    - terraform init -backend-config="key=${ENVIRONMENT}/terraform.tfstate"

validate:
  extends: .terraform-base
  stage: validate
  script:
    - terraform fmt -check
    - terraform validate
  parallel:
    matrix:
      - ENVIRONMENT: [dev, staging, prod]

plan:
  extends: .terraform-base
  stage: plan
  script:
    - terraform plan -out=plan.tfplan
  artifacts:
    paths:
      - ${TF_ROOT}/${ENVIRONMENT}/plan.tfplan
    expire_in: 7 days
  parallel:
    matrix:
      - ENVIRONMENT: [dev, staging, prod]

deploy:dev:
  extends: .terraform-base
  stage: deploy
  environment:
    name: dev
  variables:
    ENVIRONMENT: dev
  script:
    - terraform apply plan.tfplan
  dependencies:
    - plan
  only:
    - develop

deploy:staging:
  extends: .terraform-base
  stage: deploy
  environment:
    name: staging
  variables:
    ENVIRONMENT: staging
  script:
    - terraform apply plan.tfplan
  dependencies:
    - plan
  only:
    - main

deploy:prod:
  extends: .terraform-base
  stage: deploy
  environment:
    name: production
  variables:
    ENVIRONMENT: prod
  script:
    - terraform apply plan.tfplan
  dependencies:
    - plan
  when: manual
  only:
    - tags
```

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

## Points clés à retenir

1. **Isolation** : Chaque environnement doit être complètement isolé
2. **Réutilisation** : Maximiser la réutilisation du code via les modules
3. **Configuration** : Centraliser les différences dans des fichiers de variables
4. **Sécurité** : Implémenter des contrôles stricts pour la production
5. **Automatisation** : Utiliser des pipelines CI/CD pour réduire les erreurs

## Ressources supplémentaires

- [Terraform State Management](https://www.terraform.io/docs/state/index.html)
- [AWS Well-Architected Framework - Reliability Pillar](https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/welcome.html)
- [HashiCorp Best Practices for Multi-Environment](https://learn.hashicorp.com/tutorials/terraform/organize-configuration)

## Conclusion : bonnes pratiques de gestion multi-environnements

### Convention de structure

- **environments/** : Séparation claire par environnement  
- **modules/** : Code réutilisable et centralisé
- **scripts/** : Automation et déploiement
- **global/** : Configuration partagée

### Séparation des responsabilités

Chaque environnement doit avoir :
- Son propre état Terraform isolé
- Des configurations spécifiques mais cohérentes
- Des mécanismes de protection adaptés au niveau de criticité

### Automatisation et sécurité

L'approche par répertoires facilite :
- L'intégration dans des pipelines CI/CD
- La mise en place de contrôles d'accès différenciés
- La validation et les tests automatisés

Cette structure multi-environnements fournit une base solide pour gérer des infrastructures complexes en production tout en maintenant la simplicité de développement et la sécurité nécessaire.