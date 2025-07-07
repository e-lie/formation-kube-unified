# environments/staging/terragrunt.hcl
include "root" {
  path = find_in_parent_folders("_common/terragrunt.hcl")
}

terraform {
  source = "../../main-infrastructure"
}

inputs = {
  feature_name   = "staging"
  instance_count = 2
  instance_type  = "t2.small"
  
  # CIDR spécifiques à staging
  vpc_cidr             = "10.1.0.0/16"
  public_subnet_cidr   = "10.1.1.0/24"
  public_subnet_cidr_2 = "10.1.2.0/24"
}