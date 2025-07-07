terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "terraform-state-<YOUR-BUCKET-NAME>"
    key            = "tp-fil-rouge-dev/terraform.tfstate"
    region         = "eu-west-3"
    profile        = "default"
    encrypt        = true
    use_lockfile   = true
    dynamodb_table = "terraform-state-lock"
  }
}