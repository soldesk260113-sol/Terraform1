terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# --------------------------------------------------------------------------------
# 1. Safety & Control (EventBridge Rule acting as a switch)
# --------------------------------------------------------------------------------

# Rule in US-East-1 (Source of Alarm Change)
resource "aws_cloudwatch_event_rule" "failover_trigger_us_east_1" {
  provider       = aws.us_east_1
  name           = "dr-failover-trigger-rule"
  description    = "Route53 장애 알람을 리전 간 전달 (Source Region)"
  event_bus_name = "default"

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    detail = {
      state     = { value = ["ALARM", "OK"] }
      alarmName = [var.alarm_name] # Reverted: only on-prem failover triggers automation
    }
  })
}

# IAM Role for EventBridge to PutEvents to Target Region
resource "aws_iam_role" "eventbridge_cross_region" {
  provider = aws.us_east_1
  name     = "dr-eventbridge-cross-region-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_policy" "eventbridge_cross_region_policy" {
  provider = aws.us_east_1
  name     = "dr-eventbridge-cross-region-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["events:PutEvents"]
        Resource = ["arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:event-bus/default"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eventbridge_cross_region_attach" {
  provider   = aws.us_east_1
  role       = aws_iam_role.eventbridge_cross_region.name
  policy_arn = aws_iam_policy.eventbridge_cross_region_policy.arn
}

# Target: Application Region Event Bus
resource "aws_cloudwatch_event_target" "target_region_bus" {
  provider  = aws.us_east_1
  rule      = aws_cloudwatch_event_rule.failover_trigger_us_east_1.name
  target_id = "TargetRegionEventBus"
  arn       = "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:event-bus/default"
  role_arn  = aws_iam_role.eventbridge_cross_region.arn
}

# --------------------------------------------------------------------------------
# 2. Detection & Alert (Route53, CloudWatch, SQS)
# --------------------------------------------------------------------------------

# 2-1. SQS Queue in Application Region
resource "aws_sqs_queue" "failover_queue" {
  name                       = var.dr_failover_queue_name
  visibility_timeout_seconds = 300
  message_retention_seconds  = 345600 # 4 days
}

# Queue Policy to allow EventBridge
resource "aws_sqs_queue_policy" "failover_queue_policy" {
  queue_url = aws_sqs_queue.failover_queue.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.failover_queue.arn
      }
    ]
  })
}

# 2-2. Relay Rule in Application Region (Seoul)
# This rule catches events forwarded from US-East-1 bus to the local default bus
resource "aws_cloudwatch_event_rule" "failover_relay_ap_ne_2" {
  name        = "dr-failover-relay-rule"
  description = "US-East-1에서 넘어온 장애 알람을 SQS로 전달"
  
  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    detail = {
      state     = { value = ["ALARM", "OK"] }
      alarmName = [var.alarm_name]
    }
  })
}

resource "aws_cloudwatch_event_target" "sqs_target_ap_ne_2" {
  rule      = aws_cloudwatch_event_rule.failover_relay_ap_ne_2.name
  target_id = "ForwardToSQS"
  arn       = aws_sqs_queue.failover_queue.arn
}

# 2-2. Succession Completion Signal Queue
resource "aws_sqs_queue" "succession_complete" {
  name                       = "dr-succession-complete-queue"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 345600
}


# --------------------------------------------------------------------------------
# 3. Execution & Recovery (VPC Endpoints, IAM, K8s)
# --------------------------------------------------------------------------------

# 3-1. VPC Interface Endpoints
# Security Group allowing HTTPS from VPC CIDR should be passed in var.security_group_ids

resource "aws_vpc_endpoint" "sqs" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.sqs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = var.security_group_ids
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "rds" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.rds"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = var.security_group_ids
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = var.security_group_ids
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = var.security_group_ids
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = var.security_group_ids
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "monitoring" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.monitoring"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = var.security_group_ids
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.private_route_table_ids
}

# 3-2. IAM Role for Service Account (IRSA)

