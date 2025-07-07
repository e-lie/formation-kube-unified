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
# Remplacez <YOUR-BUCKET-NAME> et default par vos valeurs
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