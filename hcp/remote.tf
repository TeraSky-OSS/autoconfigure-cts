terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "TeraSky"

    workspaces {
      name = "hcp-non-partner"
    }
  }
  required_providers {
    aws = {
      source  = "registry.terraform.io/hashicorp/aws"
      version = "4.14.0"
    }
    hcp = {
      source = "registry.terraform.io/hashicorp/hcp"
      version = "0.28.0"
    }
  }
}
