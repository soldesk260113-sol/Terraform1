variable "environment" {
  description = "Application environment (e.g. dr, prod)"
  type        = string
}

variable "region" {
  description = "Primary region for resources (Default: ap-northeast-2). Note: Route53 Health Check metrics are always in us-east-1."
  type        = string
  default     = "ap-northeast-2"
}

variable "vpc_id" {
  description = "VPC ID where workloads and endpoints reside"
  type        = string
}

variable "subnet_ids" {
  description = "List of private subnet IDs for endpoints and workloads"
  type        = list(string)
}

variable "private_route_table_ids" {
  description = "List of private route table IDs for S3 Gateway Endpoint"
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "List of security group IDs for endpoints (optional)"
  type        = list(string)
  default     = []
}

variable "primary_target_domain" {
  description = "Target domain for the Primary environment (e.g. Ngrok URL) to check for health"
  type        = string
}

variable "health_check_type" {
  description = "Health Check protocol: HTTP or HTTPS"
  type        = string
  default     = "HTTP"
}

variable "health_check_port" {
  description = "Health Check port: 80 or 443"
  type        = number
  default     = 80
}

variable "dr_failover_queue_name" {
  description = "Name of the SQS queue for failover triggers"
  type        = string
  default     = "dr-failover-queue"
}

variable "alarm_name" {
  description = "Name of the CloudWatch Alarm for route53 health check failure"
  type        = string
  default     = "dr-onprem-failure-alarm"
}

variable "rds_cluster_identifier" {
  description = "Identifier of the RDS instance/cluster to promote"
  type        = string
}

variable "cluster_oidc_provider_arn" {
  description = "IAM OIDC Provider ARN for the ROSA/EKS cluster to associate with the Service Account"
  type        = string
}

variable "cluster_service_account_namespace" {
  description = "Kubernetes namespace for the DR worker"
  type        = string
  default     = "dr-system"
}

variable "cluster_service_account_name" {
  description = "Kubernetes ServiceAccount name for the DR worker"
  type        = string
  default     = "dr-worker-sa"
}

variable "worker_image_url" {
  description = "ECR Image URL for the worker deployment"
  type        = string
}

variable "target_deployment_name" {
  description = "Name of the deployment to scale/modify on failover"
  type        = string
}
