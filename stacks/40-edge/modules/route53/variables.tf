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
