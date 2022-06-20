terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "TeraSky"

    workspaces {
      name = "aws"
    }
  }
  required_providers {
    aws = {
      source  = "registry.terraform.io/hashicorp/aws"
      version = "4.14.0"
    }
  }
}