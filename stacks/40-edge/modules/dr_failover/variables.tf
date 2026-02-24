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

variable "openshift_api_url" {
  description = "OpenShift API URL to scale deployments during failover"
  type        = string
}

variable "openshift_token" {
  description = "OpenShift Service Account Token with edit permissions in the target namespace"
  type        = string
  sensitive   = true
}

# --- DMS Task Variables ---
variable "forward_task_arn" {
  description = "DMS Forward Task ARN (On-prem -> AWS)"
  type        = string
  default     = ""
}

variable "reverse_task_arn" {
  description = "DMS Reverse Task ARN (AWS -> On-prem)"
  type        = string
  default     = ""
}

variable "onprem_host" {
  description = "On-premise database host (Tailscale IP)"
  type        = string
  default     = ""
}
