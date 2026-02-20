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

#############################################
# Remote State: 00-base-network outputs 참조
#############################################
data "terraform_remote_state" "base" {
  backend = "local"
  config = {
    path = "../../00-base-network/envs/dev/terraform.tfstate"
  }
}

locals {
  vpc_id                  = data.terraform_remote_state.base.outputs.vpc_id
  private_route_table_ids = data.terraform_remote_state.base.outputs.private_route_table_ids
}

#############################################
# Site-to-Site VPN (VGW 기반)
#############################################
module "s2s_vpn" {
  source = "../../modules/s2s_vpn_vgw"

  name             = var.name
  vpc_id           = local.vpc_id
  onprem_public_ip = var.onprem_public_ip
  onprem_cidr      = var.onprem_cidr
  cgw_bgp_asn      = 65000

  static_routes_only = true
  route_table_ids    = local.private_route_table_ids
}

#############################################
# VPN 테스트용 Security Group
#############################################
module "vpn_test_sg" {
  source = "../../modules/security_sg"

  name        = "${var.name}-vpn-test-sg"
  vpc_id      = local.vpc_id
  onprem_cidr = var.onprem_cidr

  allow_icmp = true
  allow_ssh  = true
}

