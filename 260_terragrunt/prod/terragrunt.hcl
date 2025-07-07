# prod/terragrunt.hcl
include "root" {
  path = find_in_parent_folders("_common/terragrunt.hcl")
}

terraform {
  source = "../main-infrastructure"
}

inputs = {
  feature_name   = "prod"
  instance_count = 3
  instance_type  = "t2.small"
  
  # CIDR spécifiques à prod
  vpc_cidr             = "10.2.0.0/16"
  public_subnet_cidr   = "10.2.1.0/24"
  public_subnet_cidr_2 = "10.2.2.0/24"
}