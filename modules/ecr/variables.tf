variable "environment" {
  description = "Environment name (e.g., dr)"
  type        = string
}

variable "repositories" {
  description = "List of ECR repository names"
  type        = list(string)
  default     = ["web-v2", "energy-api"]
}
