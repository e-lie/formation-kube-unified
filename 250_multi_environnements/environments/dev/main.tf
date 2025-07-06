terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Backend configuré dynamiquement
  backend "s3" {}
}

# Configuration du provider AWS
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# Module VPC
module "vpc" {
  source = "../../modules/vpc"
  
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidr   = var.public_subnet_cidr
  public_subnet_cidr_2 = var.public_subnet_cidr_2
  workspace            = "dev"
  feature_name         = var.feature_name
  instance_count       = var.instance_count
}

# Module Webserver
module "webserver" {
  source = "../../modules/webserver"
  
  instance_count    = var.instance_count
  instance_type     = var.instance_type
  subnet_id         = module.vpc.public_subnet_ids[0]
  security_group_id = module.vpc.web_servers_security_group_id
  ssh_key_path      = var.ssh_key_path
  workspace         = "dev"
  feature_name      = var.feature_name
}

# Module Load Balancer
module "loadbalancer" {
  source = "../../modules/loadbalancer"
  
  instance_count     = var.instance_count
  workspace          = "dev"
  feature_name       = var.feature_name
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.public_subnet_ids
  security_group_ids = module.vpc.alb_security_group_ids
  instance_ids       = module.webserver.instance_ids
}