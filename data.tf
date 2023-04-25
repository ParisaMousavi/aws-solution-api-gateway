data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = var.terraform_remote_state_bucket
    key    = "enterprise-network/terraform.tfstate"
    region = "eu-central-1"
  }
}

