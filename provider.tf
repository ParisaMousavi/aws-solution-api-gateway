terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.33.0"
    }
  }
  backend "s3" {
    bucket = "terraform-myproje-euc1-dev"
    key    = "solution-api-gateway/terraform.tfstate"
    region = "eu-central-1"
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  type    = string
  default = "eu-central-1"
}
