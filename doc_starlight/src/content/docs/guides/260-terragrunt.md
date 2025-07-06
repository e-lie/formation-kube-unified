---
title: "README"
description: "Guide README"
sidebar:
  order: 260
---

# Part 11 : Terragrunt - Simplification multi-environnements

Cette partie démontre comment Terragrunt simplifie la gestion multi-environnements en éliminant la duplication de code de la Part 10.

## Structure du projet

```
260_terragrunt/
├── _common/
│   └── terragrunt.hcl          # Configuration partagée
├── main-infrastructure/        # Module principal unifié
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── modules/                    # Modules copiés de Part 10
│   ├── vpc/
│   ├── webserver/
│   └── loadbalancer/
├── dev/
│   └── terragrunt.hcl         # Config spécifique dev
├── staging/
│   └── terragrunt.hcl         # Config spécifique staging
├── prod/
│   └── terragrunt.hcl         # Config spécifique prod
├── scripts/
│   └── migrate-from-part10.sh # Script de migration
└── terragrunt.hcl             # Config racine
```

## Avantages vs Part 10

| Aspect | Part 10 | Part 11 Terragrunt |
|--------|---------|-------------------|
| **Duplication** | 3 fichiers main.tf identiques | 1 seul module principal |
| **Backend** | Configuration répétée 3 fois | Configuration centralisée |
| **Maintenance** | Modification en 3 endroits | Modification unique |
| **Variables** | Dispersées | Hiérarchie claire |

## Installation et utilisation

```bash
# Installation Terragrunt
curl -LO "https://github.com/gruntwork-io/terragrunt/releases/latest/download/terragrunt_linux_amd64"
sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt
sudo chmod +x /usr/local/bin/terragrunt

# Commandes de base
cd dev
terragrunt init
terragrunt plan
terragrunt apply

# Commandes multi-environnements
terragrunt run-all plan
terragrunt run-all apply
```

## Migration depuis Part 10

```bash
# Utiliser le script de migration fourni
./scripts/migrate-from-part10.sh
```

Cette implémentation démontre concrètement les avantages de Terragrunt pour gérer efficacement des infrastructures multi-environnements avec Terraform.