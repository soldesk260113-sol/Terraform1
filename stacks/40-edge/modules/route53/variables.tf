variable "domain_name" {
  type = string
}

variable "alb_dns_name" {
  type = string
}

variable "alb_zone_id" {
  type = string
}

variable "primary_target_domain" {
  description = "Target domain for the Primary environment (e.g. Ngrok URL)"
  type        = string
}

variable "primary_health_check_id" {
  description = "Route53 Health Check ID for the Primary environment"
  type        = string
}

variable "onprem_ip" {
  description = "Tailscale IP of the on-premise database host"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Execution environment (e.g. dev, prod, dr)"
  type        = string
}

variable "alarm_email" {
  description = "Email address for operator alerts"
  type        = string
  default     = ""
}

variable "use_cloudfront_only" {
  description = "If true, DNS records will always point to CloudFront and ignore failover."
  type        = bool
  default     = false
}
