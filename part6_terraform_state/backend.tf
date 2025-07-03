terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "terraform-state-<YOUR-UNIQUE-SUFFIX>"
    key            = "part6/terraform.tfstate"
    region         = "eu-west-3"
    profile        = "laptop"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}