# Inclure la configuration commune
include "root" {
  path = find_in_parent_folders()
  expose = true
}

# Source du module Terraform
terraform {
  source = "../main-infrastructure"
}

# Variables spécifiques à l'environnement prod
inputs = {
  environment    = "prod"
  feature_name   = "prod"
  instance_count = 3
  instance_type  = "t2.medium"
}