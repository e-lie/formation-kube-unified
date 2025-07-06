# Inclure la configuration commune
include "root" {
  path = find_in_parent_folders()
  expose = true
}

# Source du module Terraform
terraform {
  source = "../main-infrastructure"
}

# Variables spécifiques à l'environnement staging
inputs = {
  environment    = "staging"
  feature_name   = "staging"
  instance_count = 2
  instance_type  = "t2.small"
}