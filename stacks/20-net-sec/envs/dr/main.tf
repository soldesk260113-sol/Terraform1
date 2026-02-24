

data "terraform_remote_state" "base" {
  backend = "s3"
  config = {
    bucket = "dr-backup-ap-northeast-2"
    key    = "stacks/10-base-network/dr/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

locals {
  vpc_id                  = data.terraform_remote_state.base.outputs.vpc_id
  private_route_table_ids = data.terraform_remote_state.base.outputs.private_route_table_ids
}

module "s2s_vpn" {
  source = "../../modules/s2s_vpn_vgw"

  name             = var.name
  vpc_id           = local.vpc_id
  onprem_public_ip = var.onprem_public_ip
  onprem_cidrs    = var.onprem_cidrs
  cgw_bgp_asn      = 65000 # TODO: 온프레미스 라우터의 실제 BGP ASN으로 변경 필요

  static_routes_only = true
  route_table_ids    = local.private_route_table_ids
}

module "vpn_sg" {
  source = "../../modules/security_sg"

  name        = "${var.name}-sg"
  vpc_id      = local.vpc_id
  onprem_cidrs = var.onprem_cidrs

  allow_icmp = true
  allow_ssh  = true
}


