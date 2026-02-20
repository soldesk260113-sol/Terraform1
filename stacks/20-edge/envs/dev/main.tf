terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

#############################################
# Remote State: 00-base-network outputs 참조
#############################################
data "terraform_remote_state" "base" {
  backend = "local"
  config = {
    # 20-edge/envs/dev 기준 상대경로
    path = "../../00-base-network/envs/dev/terraform.tfstate"
  }
}

locals {
  vpc_id            = data.terraform_remote_state.base.outputs.vpc_id
  public_subnet_ids = data.terraform_remote_state.base.outputs.public_subnet_ids
}

module "alb" {
  source = "../../modules/alb"

  name                  = var.alb_name
  vpc_id                = local.vpc_id
  public_subnet_ids     = local.public_subnet_ids
  allowed_ingress_cidrs = ["0.0.0.0/0"]
}

############################
# 🔐 AWS WAF (REGIONAL, ALB 연결)
############################

resource "aws_wafv2_web_acl" "alb_waf" {
  name  = "${var.alb_name}-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  ########################################
  # 1) Common Rule Set
  ########################################
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  ########################################
  # 2) SQLi Rule Set
  ########################################
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLiRuleSet"
      sampled_requests_enabled   = true
    }
  }

  ########################################
  # 3) Known Bad Inputs
  ########################################
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "KnownBadInputs"
      sampled_requests_enabled   = true
    }
  }

  ########################################
  # 4) Linux Rule Set
  ########################################
  rule {
    name     = "AWSManagedRulesLinuxRuleSet"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesLinuxRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "LinuxRuleSet"
      sampled_requests_enabled   = true
    }
  }

  ########################################
  # 5) Rate Limit (5분 기준 IP당 1000회 초과 차단)
  ########################################
  rule {
    name     = "RateLimitPerIP"
    priority = 10

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 1000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimit"
      sampled_requests_enabled   = true
    }
  }

  ########################################
  # WebACL 전체 메트릭
  ########################################
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "AlbWaf"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "alb_assoc" {
  resource_arn = module.alb.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.alb_waf.arn
}

