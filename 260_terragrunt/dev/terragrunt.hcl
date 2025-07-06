# Inclure la configuration commune
include "root" {
  path = find_in_parent_folders()
  expose = true
}

# Source du module Terraform
terraform {
  source = "../main-infrastructure"
}

# Variables spécifiques à l'environnement dev
inputs = {
  environment    = "dev"
  feature_name   = "dev"
  instance_count = 1
  instance_type  = "t2.micro"
}