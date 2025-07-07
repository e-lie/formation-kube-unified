# dev/terragrunt.hcl
include "root" {
  path = find_in_parent_folders("_common/terragrunt.hcl")
}

terraform {
  source = "../main-infrastructure"
}

inputs = {
  feature_name   = "dev"
  instance_count = 1
  instance_type  = "t2.micro"
  
  # CIDR spécifiques à dev
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidr   = "10.0.1.0/24"
  public_subnet_cidr_2 = "10.0.2.0/24"
}