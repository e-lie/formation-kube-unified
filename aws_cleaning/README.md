# 🧹 AWS Cleaning Toolkit

Suite complète d'outils pour auditer et nettoyer les ressources AWS avec une approche TOML pour la traçabilité et le contrôle.

## 📦 Scripts disponibles

### Scripts EC2 spécialisés
- **`ec2-list-to-toml.py`** - Liste les instances EC2 et exporte en TOML
- **`ec2-terminate-from-toml.py`** - Termine les instances EC2 depuis un fichier TOML

### Scripts multi-ressources (nouveaux)
- **`aws-resources-to-toml.py`** - Scanner universel pour toutes les ressources AWS
- **`aws-delete-from-toml.py`** - Suppression intelligente avec gestion des dépendances

### Scripts utilitaires
- **`test-multi-resources.py`** - Tests automatisés pour valider les fonctionnalités

## 🎯 Types de ressources supportées

| Type | Nom | Portée | Description |
|------|-----|--------|-------------|
| `ec2` | EC2 Instances | Régional | Machines virtuelles |
| `vpc` | VPCs | Régional | Réseaux virtuels privés |
| `subnet` | Subnets | Régional | Sous-réseaux |
| `sg` | Security Groups | Régional | Groupes de sécurité |
| `elb` | Classic Load Balancers | Régional | Anciens load balancers |
| `elbv2` | ALB/NLB | Régional | Application/Network LB |
| `igw` | Internet Gateways | Régional | Passerelles Internet |
| `nat` | NAT Gateways | Régional | Passerelles NAT |
| `rt` | Route Tables | Régional | Tables de routage |
| `rds` | RDS Instances | Régional | Bases de données |
| `ami` | AMIs (Images) | Régional | Images de machines virtuelles |
| `s3` | S3 Buckets | Global | Stockage objet |

## 🚀 Guide d'utilisation rapide

### 1. Scanner toutes les ressources

```bash
# Scanner tout dans toutes les régions
./aws-resources-to-toml.py --output audit-complet.toml

# Scanner seulement certaines ressources
./aws-resources-to-toml.py --resource-types ec2 vpc sg --output infra-compute.toml

# Scanner une région spécifique
./aws-resources-to-toml.py --regions eu-west-3 --output eu-west-3.toml
```

### 2. Analyser les résultats

```bash
# Voir le résumé
./aws-delete-from-toml.py audit-complet.toml --summary-only

# Lister les types disponibles
./aws-resources-to-toml.py --list-types
```

### 3. Simulation de suppression

```bash
# Tester la suppression de tout
./aws-delete-from-toml.py audit-complet.toml --dry-run

# Tester seulement certaines ressources
./aws-delete-from-toml.py audit-complet.toml --dry-run --resource-types ec2 rds
```

### 4. Suppression réelle

```bash
# Suppression avec confirmation
./aws-delete-from-toml.py audit-complet.toml

# Suppression forcée (pour scripts)
./aws-delete-from-toml.py audit-complet.toml --force
```

## 🔧 Exemples détaillés

### Exemple 1: Nettoyage après formation

```bash
# 1. Scan complet
./aws-resources-to-toml.py --output formation-2024.toml

# 2. Vérifier ce qui sera supprimé
./aws-delete-from-toml.py formation-2024.toml --summary-only

# 3. Test de suppression
./aws-delete-from-toml.py formation-2024.toml --dry-run

# 4. Suppression progressive (d'abord les instances)
./aws-delete-from-toml.py formation-2024.toml --resource-types ec2 rds

# 5. Puis l'infrastructure réseau
./aws-delete-from-toml.py formation-2024.toml --resource-types sg subnet igw vpc
```

### Exemple 2: Audit par environnement

```bash
# Scanner seulement l'infrastructure de compute
./aws-resources-to-toml.py \
    --resource-types ec2 elb elbv2 rds \
    --regions eu-west-1 us-east-1 \
    --output compute-audit.toml

# Analyser
./aws-delete-from-toml.py compute-audit.toml --summary-only
```

### Exemple 3: Nettoyage sélectif

```bash
# Scanner tout
./aws-resources-to-toml.py --output full-scan.toml

# Éditer le TOML pour ne garder que les ressources à supprimer
# (supprimer les sections des ressources à conserver)

# Supprimer seulement ce qui reste
./aws-delete-from-toml.py full-scan-edited.toml --dry-run
./aws-delete-from-toml.py full-scan-edited.toml
```

## 📋 Structure du fichier TOML

### Métadonnées

```toml
[metadata]
scan_date = "2024-01-15T16:30:45.123456"
profile = "default"
total_regions_scanned = 3
regions_scanned = ["eu-west-1", "eu-west-3", "us-east-1"]
resource_types_scanned = ["ec2", "vpc", "sg"]

[summary]
total_resources = 42
by_type = { ec2 = 18, vpc = 3, sg = 21 }
by_region = { "eu-west-1" = 15, "eu-west-3" = 18, "us-east-1" = 9 }
```

### Ressources régionales

```toml
[region_eu-west-3.ec2]
resource_count = 18
resource_ids = ["i-0783260ea633c9bf0", "i-0b75b3a73ea69038c", ...]

[region_eu-west-3.ec2.resources.i-0783260ea633c9bf0]
Id = "i-0783260ea633c9bf0"
State = "running"
Type = "t2.micro"
VpcId = "vpc-12345678"

[region_eu-west-3.vpc]
resource_count = 2
resource_ids = ["vpc-12345678", "vpc-87654321"]

[region_eu-west-3.vpc.resources.vpc-12345678]
Id = "vpc-12345678"
State = "available"
IsDefault = false
CidrBlock = "10.0.0.0/16"
```

### Ressources globales

```toml
[global_s3]
resource_count = 5
resource_ids = ["my-bucket-1", "logs-bucket", ...]

[global_s3.resources.my-bucket-1]
Id = "my-bucket-1"
Name = "my-bucket-1"
CreationDate = "2024-01-10T10:00:00Z"
```

## 🔄 Ordre de suppression automatique

Le script respecte automatiquement les dépendances AWS :

1. **RDS Instances** (pas de dépendances)
2. **Load Balancers** (ELB, ALB, NLB)
3. **EC2 Instances**
4. **NAT Gateways**
5. **Route Tables** (non-principales)
6. **Security Groups** (non-default)
7. **Subnets**
8. **Internet Gateways**
9. **VPCs** (en dernier)
10. **AMIs** (images et snapshots associés)
11. **S3 Buckets** (global)

## 🛡️ Sécurités intégrées

### Filtres automatiques
- **VPCs par défaut** : Exclus automatiquement
- **Security Groups "default"** : Exclus automatiquement
- **Route Tables principales** : Exclus automatiquement
- **Ressources AWS managées** : Exclus automatiquement

### Vérifications
- ✅ Vérification de l'existence avant suppression
- ✅ Gestion des dépendances (détachement automatique)
- ✅ Mode dry-run obligatoire en premier
- ✅ Confirmation explicite requise
- ✅ Logs détaillés de chaque action

### Protection contre les erreurs
- 🔒 Détachement automatique des IGW avant suppression
- 🔒 Vidage automatique des buckets S3
- 🔒 Suppression des versions S3
- 🔒 Gestion des timeouts et retry
- 🔒 Pause entre suppressions pour éviter le throttling

## ⚙️ Configuration et prérequis

### Installation

```bash
# Dépendances Python
pip install toml

# Permissions AWS CLI
aws configure  # ou utiliser des profils
```

### Permissions IAM minimales

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "ec2:TerminateInstances",
        "ec2:DeleteVpc",
        "ec2:DeleteSubnet",
        "ec2:DeleteSecurityGroup",
        "ec2:DeleteInternetGateway",
        "ec2:DetachInternetGateway",
        "ec2:DeleteNatGateway",
        "ec2:DeleteRouteTable",
        "ec2:DeregisterImage",
        "ec2:DeleteSnapshot",
        "elasticloadbalancing:Describe*",
        "elasticloadbalancing:DeleteLoadBalancer",
        "rds:Describe*",
        "rds:DeleteDBInstance",
        "s3:ListAllMyBuckets",
        "s3:DeleteBucket",
        "s3:DeleteObject",
        "s3:DeleteObjectVersion",
        "s3:ListBucket",
        "s3:ListBucketVersions"
      ],
      "Resource": "*"
    }
  ]
}
```

## 📊 Cas d'usage avancés

### Script de nettoyage quotidien

```bash
#!/bin/bash
# cleanup-daily.sh

DATE=$(date +%Y%m%d)
LOG_FILE="cleanup-${DATE}.log"

echo "🧹 Nettoyage quotidien AWS - ${DATE}" | tee -a $LOG_FILE

# Scanner les ressources temporaires
./aws-resources-to-toml.py \
    --resource-types ec2 rds \
    --output "daily-scan-${DATE}.toml" | tee -a $LOG_FILE

# Supprimer en dry-run d'abord
./aws-delete-from-toml.py "daily-scan-${DATE}.toml" \
    --dry-run | tee -a $LOG_FILE

# Demander confirmation pour la suppression réelle
read -p "Procéder à la suppression ? (y/N): " confirm
if [[ $confirm == "y" ]]; then
    ./aws-delete-from-toml.py "daily-scan-${DATE}.toml" \
        --force | tee -a $LOG_FILE
fi

echo "✅ Nettoyage terminé" | tee -a $LOG_FILE
```

### Audit de conformité

```bash
# Générer un rapport d'audit complet
./aws-resources-to-toml.py \
    --output "audit-$(date +%Y%m).toml"

# Extraire des statistiques
python3 << EOF
import toml
data = toml.load('audit-$(date +%Y%m).toml')
print(f"Total ressources: {data['summary']['total_resources']}")
for rtype, count in data['summary']['by_type'].items():
    print(f"  {rtype}: {count}")
EOF
```

## 🚨 Avertissements importants

1. **Toujours tester avec `--dry-run` d'abord**
2. **Les suppressions sont irréversibles**
3. **Vérifier le compte AWS actif**
4. **Sauvegarder les données importantes**
5. **Tester sur un environnement de dev**

## 🐛 Dépannage

### Erreur "Access Denied"
```bash
# Vérifier les permissions
aws sts get-caller-identity
aws iam get-user
```

### Ressources non supprimées
```bash
# Vérifier les dépendances
aws ec2 describe-vpc-attribute --vpc-id vpc-xxx --attribute enableDnsSupport
```

### Timeout ou throttling
- Les scripts incluent des pauses automatiques
- Relancer le script, il reprendra où il s'était arrêté

## 📈 Métriques et monitoring

```bash
# Générer des métriques
./aws-resources-to-toml.py --output metrics.toml
python3 << EOF
import toml, json
data = toml.load('metrics.toml')
metrics = {
    'timestamp': data['metadata']['scan_date'],
    'total_resources': data['summary']['total_resources'],
    'by_type': data['summary']['by_type'],
    'by_region': data['summary']['by_region']
}
print(json.dumps(metrics, indent=2))
EOF
```

Cette suite d'outils offre une approche complète, sécurisée et traçable pour la gestion des ressources AWS ! 🎯