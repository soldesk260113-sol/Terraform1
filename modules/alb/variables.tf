variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

# HTTPS 인증서 ARN (Route53 모듈에서 전달받음)
variable "certificate_arn" {
  description = "ACM Certificate ARN for HTTPS listener"
  type        = string
  default     = "" # Optional initially
}
