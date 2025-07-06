# _common/terragrunt.hcl
remote_state {
  backend = "s3"
  config = {
    bucket         = "terraform-state-<YOUR-BUCKET-NAME>"
    key            = "tp-fil-rouge-${path_relative_to_include()}/terraform.tfstate"
    region         = "eu-west-3"
    profile        = "<awsprofile-votreprenom>"
    encrypt        = true
    use_lockfile   = true
    dynamodb_table = "terraform-state-lock"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Génération automatique du provider
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}
EOF
}

# Variables communes à tous les environnements
inputs = {
  aws_region   = "eu-west-3"
  aws_profile  = "<awsprofile-votreprenom>"
  ssh_key_path = "~/.ssh/id_terraform"
}