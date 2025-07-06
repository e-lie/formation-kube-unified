#!/bin/bash
set -e

echo "🔄 Migration de Part 10 vers Terragrunt..."

# Créer le répertoire de scripts
mkdir -p scripts

# Sauvegarder les états existants
echo "📦 Sauvegarde des états existants..."
for env in dev staging prod; do
    if [ -d "../250_multi_environnements/environments/$env" ]; then
        cd "../250_multi_environnements/environments/$env"
        if [ -f "terraform.tfstate" ]; then
            terraform state pull > "../../../260_terragrunt/backup-${env}-$(date +%Y%m%d).tfstate"
            echo "État $env sauvegardé"
        fi
        cd - > /dev/null
    fi
done

# Importer les états dans Terragrunt
echo "📥 Import des états dans Terragrunt..."
for env in dev staging prod; do
    echo "Import de l'environnement $env..."
    cd "$env"
    
    # Initialiser Terragrunt
    terragrunt init
    
    # Importer l'état si la sauvegarde existe
    if [ -f "../backup-${env}-$(date +%Y%m%d).tfstate" ]; then
        cp "../backup-${env}-$(date +%Y%m%d).tfstate" terraform.tfstate
        echo "État $env importé"
    fi
    
    cd ..
done

echo "✅ Migration terminée!"
echo "Vous pouvez maintenant utiliser 'terragrunt' au lieu de 'terraform'"