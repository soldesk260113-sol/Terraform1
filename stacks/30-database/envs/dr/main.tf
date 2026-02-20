terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

data "terraform_remote_state" "base" {
  backend = "local"
  config = {
    path = "../../00-base-network/envs/dr/terraform.tfstate"
  }
}

data "terraform_remote_state" "net_sec" {
  backend = "local"
  config = {
    path = "../../10-net-sec/envs/dr/terraform.tfstate"
  }
}

locals {
  vpc_id              = data.terraform_remote_state.base.outputs.vpc_id
  private_subnet_ids  = data.terraform_remote_state.base.outputs.private_subnet_ids
  # Assuming 10-net-sec outputs a security group suitable for DB, or use default
  # In legacy, it used module.security.web_sg_id. Here we might need to create one or use vpn_test_sg for now as placeholder
  security_group_ids  = [data.terraform_remote_state.net_sec.outputs.vpn_test_sg_id]
}

module "rds" {
  source = "../../modules/rds"

  environment        = var.environment
  subnet_ids         = local.private_subnet_ids
  security_group_ids = local.security_group_ids
  instance_class     = var.db_instance_class
  db_username        = var.db_username
  db_password        = var.db_password
}
