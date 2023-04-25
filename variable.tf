variable "environment" {
  type    = string
  default = "dev"
}

variable "region_shortname" {
  type    = string
  default = "euc1"
}

variable "name" {
  type    = string
  default = "prg1"
}

variable "prefix" {
  type    = string
  default = "dummy"
}

variable "terraform_remote_state_bucket" {
  type    = string
  default = "terraform-myproje-euc1-dev"
}