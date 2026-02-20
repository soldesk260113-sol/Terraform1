variable "environment" {
  description = "Environment name (e.g., dr, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}
