variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "ecr_repositories" {
  description = "List of ECR repository names to create"
  type        = list(string)
  default = [
    "oauth-api",
    "web-v2-dashboard",
    "integrated-dashboard",
    "map-api",
    "energy-api",
    "kma-api",
    "dr-worker"
  ]
}
