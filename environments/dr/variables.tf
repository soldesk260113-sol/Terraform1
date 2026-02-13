variable "environment" {
  type    = string
  default = "dr"
}

variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnets" {
  type = list(string)
}

variable "private_subnets" {
  type = list(string)
}

variable "azs" {
  type = list(string)
}

variable "dr_mode" {
  description = "DR 모드 활성화 (리소스 확장)"
  type        = bool
  default     = false
}

variable "domain_name" {
  type = string
}

# 온프레미스(Primary) 공인 IP
# 온프레미스(Primary) 대상 도메인 (Ngrok 등)
variable "primary_target_domain" {
  description = "Target domain for On-Premise/Primary Site (e.g. Ngrok URL)"
  type        = string
}

variable "cluster_oidc_provider_arn" {
  description = "IAM OIDC Provider ARN for the ROSA cluster"
  type        = string
  default     = "arn:aws:iam::123456789012:oidc-provider/rh-oidc.s3.us-east-1.amazonaws.com/12345ABCDE"
}

variable "worker_image_url" {
  description = "ECR Image URL for the DR worker"
  type        = string
  default     = "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/dr-worker:latest"
}

variable "dr_failover_queue_name" {
  default = "dr-failover-queue"
}

# RDS 설정
variable "db_instance_class" {
  description = "RDS instance type"
  type        = string
  default     = "db.t3.medium"
}

variable "db_username" {
  description = "Database admin username"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Database admin password"
  type        = string
  sensitive   = true
  default     = "password123"
}
