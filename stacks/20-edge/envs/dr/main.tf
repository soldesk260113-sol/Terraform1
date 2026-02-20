terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
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

data "terraform_remote_state" "database" {
  backend = "local"
  config = {
    path = "../../30-database/envs/dr/terraform.tfstate"
  }
}

locals {
  vpc_id                  = data.terraform_remote_state.base.outputs.vpc_id
  public_subnet_ids       = data.terraform_remote_state.base.outputs.public_subnet_ids
  private_subnet_ids      = data.terraform_remote_state.base.outputs.private_subnet_ids
  private_route_table_ids = data.terraform_remote_state.base.outputs.private_route_table_ids
  # Use VPN Test SG as placeholder for now, or assume this stack creates its own SG if needed
  security_group_ids      = [data.terraform_remote_state.net_sec.outputs.vpn_test_sg_id]
  db_instance_id          = data.terraform_remote_state.database.outputs.db_instance_id
}

# ALB Module
module "alb" {
  source = "../../modules/alb"
  
  name                  = "${var.environment}-dr-alb"
  vpc_id                = local.vpc_id
  public_subnet_ids     = local.public_subnet_ids
  allowed_ingress_cidrs = ["0.0.0.0/0"]
  certificate_arn       = module.route53.certificate_arn
}

# Route53 Module
module "route53" {
  source = "../../modules/route53"

  domain_name             = var.domain_name
  alb_dns_name            = module.alb.dns_name
  alb_zone_id             = module.alb.zone_id
  primary_target_domain   = var.primary_target_domain
  primary_health_check_id = module.dr_failover.health_check_id
}

# DR Failover Module
module "dr_failover" {
  source = "../../modules/dr_failover"
  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  environment             = var.environment
  region                  = var.region
  vpc_id                  = local.vpc_id
  subnet_ids              = local.private_subnet_ids
  private_route_table_ids = local.private_route_table_ids
  security_group_ids      = local.security_group_ids

  primary_target_domain     = var.primary_target_domain
  cluster_oidc_provider_arn = var.cluster_oidc_provider_arn
  worker_image_url          = var.worker_image_url
  
  health_check_type      = "HTTPS"
  health_check_port      = 443
  alarm_name             = "On-Prem-Disaster-Alarm"
  dr_failover_queue_name = "DR-Failover-Queue"

  rds_cluster_identifier = local.db_instance_id
  target_deployment_name = "web-service"
  alarm_email            = var.alarm_email
}
