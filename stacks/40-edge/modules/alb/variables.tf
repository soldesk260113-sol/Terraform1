variable "name" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }

variable "allowed_ingress_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "certificate_arn" {
  description = "ACM Certificate ARN for HTTPS listener. If provided, HTTP redirects to HTTPS."
  type        = string
  default     = ""
}

