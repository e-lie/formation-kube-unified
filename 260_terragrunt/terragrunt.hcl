# Configuration Terragrunt racine

# Import de la configuration commune
include {
  path = find_in_parent_folders("_common/terragrunt.hcl")
}

# Génération automatique des variables Terraform
generate "terraform_vars" {
  path      = "terraform.tfvars"
  if_exists = "overwrite"
  contents  = <<EOF
# Variables générées automatiquement par Terragrunt
# Ne pas modifier manuellement
aws_region = "${include.root.inputs.aws_region}"
aws_profile = "${include.root.inputs.aws_profile}"
vpc_cidr = "${include.root.inputs.vpc_cidr}"
public_subnet_cidr = "${include.root.inputs.public_subnet_cidr}"
public_subnet_cidr_2 = "${include.root.inputs.public_subnet_cidr_2}"
ssh_key_path = "${include.root.inputs.ssh_key_path}"
EOF
}

# Génération automatique de la configuration provider
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
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
EOF
}