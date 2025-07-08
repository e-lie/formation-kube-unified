# Scripts EC2 avec AWS CLI et TOML

Ces scripts Python utilisent l'AWS CLI (au lieu de boto3) pour gérer les instances EC2 avec le format TOML.

## 📦 Scripts inclus

1. **`ec2-list-to-toml.py`** - Liste les instances EC2 et exporte en TOML
2. **`ec2-terminate-from-toml.py`** - Lit un fichier TOML et termine les instances listées

## 🎯 Avantages de cette approche

- ✅ Utilise AWS CLI (plus simple à configurer)
- ✅ Format TOML lisible et éditable
- ✅ Séparation claire entre l'audit et l'action
- ✅ Possibilité de modifier le fichier TOML avant terminaison
- ✅ Traçabilité complète des actions

## 📋 Script 1: ec2-list-to-toml.py

### Fonctionnalités

- Scanne toutes les régions AWS (ou une sélection)
- Exporte les instances EC2 au format TOML
- Inclut métadonnées, résumés et détails par région
- Gère les tags importants (Name, Owner, Environment, Project)

### Utilisation

```bash
# Scan basique (toutes les régions)
./ec2-list-to-toml.py

# Avec un profil AWS spécifique
./ec2-list-to-toml.py --profile production

# Scanner seulement certaines régions
./ec2-list-to-toml.py --regions eu-west-1 us-east-1

# Spécifier le fichier de sortie
./ec2-list-to-toml.py --output my-instances.toml

# Vérifier la configuration AWS
./ec2-list-to-toml.py --check-cli --profile dev
```

### Exemple de fichier TOML généré

```toml
[metadata]
scan_date = "2024-01-15T16:30:45.123456"
profile = "default"
total_regions_scanned = 16
regions_scanned = ["eu-west-1", "us-east-1", "us-west-2", ...]

[summary]
total_instances = 5
by_region = { "eu-west-1" = 3, "us-east-1" = 2 }
by_state = { "running" = 3, "stopped" = 2 }

[regions.eu-west-1]
instance_count = 3

[regions.eu-west-1.instances.instance_1_i-0123456789abcdef0]
InstanceId = "i-0123456789abcdef0"
InstanceType = "t3.micro"
State = "running"
LaunchTime = "2024-01-10 14:23:00 UTC"
PrivateIpAddress = "10.0.1.100"
PublicIpAddress = "54.123.45.67"
VpcId = "vpc-12345678"
AvailabilityZone = "eu-west-1a"
Name = "web-server-01"
Owner = "john.doe"
Environment = "production"
Project = "ecommerce"

[regions.eu-west-1.instances.instance_2_i-0987654321fedcba0]
InstanceId = "i-0987654321fedcba0"
InstanceType = "t3.small"
State = "stopped"
LaunchTime = "2024-01-08 09:15:00 UTC"
PrivateIpAddress = "10.0.1.101"
PublicIpAddress = ""
VpcId = "vpc-12345678"
AvailabilityZone = "eu-west-1b"
Name = "test-server"
Owner = "jane.smith"
Environment = "development"
Project = "testing"
```

## 🗑️ Script 2: ec2-terminate-from-toml.py

### Fonctionnalités

- Lit un fichier TOML généré par le premier script
- Vérifie l'existence actuelle des instances
- Filtre par état (évite les instances déjà terminées)
- Mode dry-run pour simulation
- Demande confirmation avant terminaison

### Utilisation

```bash
# Voir le résumé du fichier TOML
./ec2-terminate-from-toml.py ec2_instances_20240115.toml --summary-only

# Mode dry-run (simulation)
./ec2-terminate-from-toml.py ec2_instances_20240115.toml --dry-run

# Terminer avec confirmation
./ec2-terminate-from-toml.py ec2_instances_20240115.toml

# Terminer sans confirmation (dangereux!)
./ec2-terminate-from-toml.py ec2_instances_20240115.toml --force

# Terminer seulement certains états
./ec2-terminate-from-toml.py ec2_instances_20240115.toml --states running stopped

# Avec un profil AWS spécifique
./ec2-terminate-from-toml.py ec2_instances_20240115.toml --profile production
```

### Options de filtrage

- `--states` : Filtre par état (défaut: running, stopped, pending, stopping)
- `--dry-run` : Simulation sans terminaison réelle
- `--force` : Pas de demande de confirmation
- `--summary-only` : Affiche seulement les statistiques

## 🔄 Workflow complet

### Étape 1: Audit

```bash
# Scanner toutes les instances
./ec2-list-to-toml.py --profile formation --output audit-2024-01-15.toml

# Vérifier le contenu
./ec2-terminate-from-toml.py audit-2024-01-15.toml --summary-only
```

### Étape 2: Édition sélective (optionnel)

Vous pouvez éditer le fichier TOML pour :
- Supprimer des instances à préserver
- Ajouter des commentaires
- Modifier des métadonnées

```toml
# Exemple d'édition
[regions.eu-west-1.instances.instance_1_i-0123456789abcdef0]
InstanceId = "i-0123456789abcdef0"
# GARDER CETTE INSTANCE - SERVEUR DE PRODUCTION
State = "terminated"  # Changer l'état pour l'exclure
```

### Étape 3: Simulation

```bash
# Tester ce qui serait supprimé
./ec2-terminate-from-toml.py audit-2024-01-15.toml --dry-run
```

### Étape 4: Terminaison

```bash
# Terminer avec confirmation
./ec2-terminate-from-toml.py audit-2024-01-15.toml

# Ou forcer (pour scripts automatisés)
./ec2-terminate-from-toml.py audit-2024-01-15.toml --force
```

## 📊 Exemples de cas d'usage

### Nettoyage après formation

```bash
# 1. Auditer toutes les instances
./ec2-list-to-toml.py --profile formation --output formation-cleanup.toml

# 2. Voir le résumé
./ec2-terminate-from-toml.py formation-cleanup.toml --summary-only

# 3. Tester la suppression
./ec2-terminate-from-toml.py formation-cleanup.toml --dry-run

# 4. Supprimer seulement les instances de test
./ec2-terminate-from-toml.py formation-cleanup.toml --states running stopped
```

### Nettoyage par environnement

Après avoir généré le TOML, éditez-le pour garder seulement les instances avec `Environment = "test"` puis :

```bash
./ec2-terminate-from-toml.py instances.toml --force
```

### Audit régulier

```bash
# Script quotidien d'audit
#!/bin/bash
DATE=$(date +%Y%m%d)
./ec2-list-to-toml.py --output "audit-${DATE}.toml"
echo "Audit sauvegardé dans audit-${DATE}.toml"
```

## 🛡️ Sécurités intégrées

1. **Vérification d'existence** : Les instances sont re-vérifiées avant terminaison
2. **Filtrage par état** : Les instances `terminated` sont automatiquement exclues
3. **Confirmation obligatoire** : Sauf avec `--force`
4. **Mode dry-run** : Simulation complète disponible
5. **Logs détaillés** : Chaque action est tracée

## 📋 Prérequis

- Python 3.6+
- AWS CLI configuré
- Module Python `toml`
- Permissions AWS : `ec2:DescribeInstances`, `ec2:DescribeRegions`, `ec2:TerminateInstances`

## 🚨 Avertissements

- La terminaison d'instances EC2 est **IRRÉVERSIBLE**
- Toujours utiliser `--dry-run` en premier
- Vérifier le profil AWS actif
- Les instances avec protection contre la terminaison ne seront pas supprimées

## 💡 Conseils

1. **Utilisez des tags cohérents** pour un meilleur filtrage
2. **Sauvegardez les fichiers TOML** pour l'audit
3. **Testez d'abord sur un environnement de dev**
4. **Automatisez les audits réguliers**
5. **Éditez les fichiers TOML** pour un contrôle précis