resource "aws_wafv2_web_acl" "this" {
  name  = var.name
  scope = var.scope

  # default_action: allow / block 선택
  dynamic "default_action" {
    for_each = var.default_action == "block" ? [1] : []
    content {
      block {}
    }
  }
  dynamic "default_action" {
    for_each = var.default_action == "allow" ? [1] : []
    content {
      allow {}
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = var.enable_cloudwatch_metrics
    metric_name                = var.metric_name
    sampled_requests_enabled   = true
  }

  # 1) AWS Managed Rules - Common
  dynamic "rule" {
    for_each = var.enable_managed_common ? [1] : []
    content {
      name     = "AWSManagedRulesCommonRuleSet"
      priority = 10

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
        cloudwatch_metrics_enabled = var.enable_cloudwatch_metrics
        metric_name                = "${var.metric_name}-common"
        sampled_requests_enabled   = true
      }
    }
  }

  # 2) AWS Managed Rules - Known Bad Inputs
  dynamic "rule" {
    for_each = var.enable_managed_known_bad_inputs ? [1] : []
    content {
      name     = "AWSManagedRulesKnownBadInputsRuleSet"
      priority = 20

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
        cloudwatch_metrics_enabled = var.enable_cloudwatch_metrics
        metric_name                = "${var.metric_name}-badinputs"
        sampled_requests_enabled   = true
      }
    }
  }

  # 3) AWS Managed Rules - SQLi
  dynamic "rule" {
    for_each = var.enable_managed_sqli ? [1] : []
    content {
      name     = "AWSManagedRulesSQLiRuleSet"
      priority = 30

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
        cloudwatch_metrics_enabled = var.enable_cloudwatch_metrics
        metric_name                = "${var.metric_name}-sqli"
        sampled_requests_enabled   = true
      }
    }
  }

  # 4) AWS Managed Rules - Linux
  dynamic "rule" {
    for_each = var.enable_managed_linux ? [1] : []
    content {
      name     = "AWSManagedRulesLinuxRuleSet"
      priority = 40

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
        cloudwatch_metrics_enabled = var.enable_cloudwatch_metrics
        metric_name                = "${var.metric_name}-linux"
        sampled_requests_enabled   = true
      }
    }
  }

  # 5) Rate Limit
  dynamic "rule" {
    for_each = var.enable_rate_limit ? [1] : []
    content {
      name     = "RateLimitPerIP"
      priority = 50

      action {
        block {}
      }

      statement {
        rate_based_statement {
          limit              = var.rate_limit
          aggregate_key_type = "IP"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = var.enable_cloudwatch_metrics
        metric_name                = "${var.metric_name}-ratelimit"
        sampled_requests_enabled   = true
      }
    }
  }
}

