---
title: Cours - backends
weight: 14
---


Les backends sont les intégrations terraform pour stocker l'état (`terraform.tfstate`) de façon idéalement distante, partagée et avec un mechanisme de verrouillage excluant la modification concurrente.


## Backends Cloud

### AWS
- **s3** - Amazon S3 avec verrouillage DynamoDB

```coffee
backend "s3" {
  bucket = "my-terraform-state"
  key    = "path/to/terraform.tfstate"
  region = "us-east-1"
}
```

### Azure
- **azurerm** - Azure Blob Storage avec verrouillage natif

```coffee
backend "azurerm" {
  resource_group_name  = "StorageAccount-ResourceGroup"
  storage_account_name = "abcd1234"
  container_name       = "tfstate"
  key                  = "prod.terraform.tfstate"
}
```

Autres providers de cloud.


## Backends Auto-hébergés

### Base de données
- **pg** - PostgreSQL
```coffee
backend "pg" {
  conn_str = "postgres://user:pass@db.example.com/terraform_backend?sslmode=require"
}
```

### Kubernetes
- **kubernetes** - Kubernetes Secret
```coffee
backend "kubernetes" {
  secret_suffix    = "state"
  config_path      = "~/.kube/config"
}
```

## Backends de Développement

### Local
- **local** - Système de fichiers local (défaut)
```coffee
backend "local" {
  path = "terraform.tfstate"
}
```

## Backends de Services Tiers

### Terraform Cloud
- **remote** - Terraform Cloud/Enterprise
```coffee
backend "remote" {
  organization = "example_corp"
  
  workspaces {
    name = "my-app-prod"
  }
}
```

### HTTP
- **http** - Backend HTTP générique
```coffee
backend "http" {
  address        = "https://myrest.api.com/foo"
  lock_address   = "https://myrest.api.com/foo"
  unlock_address = "https://myrest.api.com/foo"
}
```

## Compatibilité avec des solutions tierces

**MinIO** (S3-compatible) :
```coffee
backend "s3" {
  endpoint = "https://minio.example.com"
  bucket   = "terraform-state"
  key      = "terraform.tfstate"
  
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  force_path_style           = true
}
```

