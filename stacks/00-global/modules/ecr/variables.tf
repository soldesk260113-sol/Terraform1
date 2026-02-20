variable "environment" {
  description = "Environment name (e.g., dr, prod)"
  type        = string
}

variable "repositories" {
  description = "List of ECR repository names"
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
