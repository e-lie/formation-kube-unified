# Configuration commune pour tous les environnements

# Configuration du backend S3
remote_state {
  backend = "s3"
  config = {
    bucket         = "terraform-state-<YOUR-BUCKET-NAME>"
    region         = "eu-west-3"
    profile        = "<awsprofile-votreprenom>"
    encrypt        = true
    use_lockfile   = true
    dynamodb_table = "terraform-state-lock"
    
    # La clé sera générée automatiquement par Terragrunt
    key = "${path_relative_to_include()}/terraform.tfstate"
  }
}

# Configuration Terraform commune
terraform {
  # Version minimale requise
  required_version = ">= 1.0"
  
  # Providers requis
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Variables communes à tous les environnements
inputs = {
  aws_region = "eu-west-3"
  aws_profile = "<awsprofile-votreprenom>"
  vpc_cidr = "10.0.0.0/16"
  public_subnet_cidr = "10.0.1.0/24"
  public_subnet_cidr_2 = "10.0.2.0/24"
  ssh_key_path = "~/.ssh/id_terraform"
}