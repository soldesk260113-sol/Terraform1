variable "environment" { type = string }
variable "region" { type = string }
variable "domain_name" { type = string }
variable "primary_target_domain" { type = string }
variable "openshift_api_url" { type = string }
variable "openshift_token" { 
  type = string 
  sensitive = true
}
variable "alarm_email" { type = string }

# Image URLs
variable "ai_rag_image_url" { type = string }
variable "auth_chat_api_image_url" { type = string }
variable "dr_worker_image_url" { type = string }
variable "energy_api_image_url" { type = string }
variable "kma_api_image_url" { type = string }
variable "redis_image_url" { type = string }
variable "web_dash_image_url" { type = string }

# API Variables
variable "kma_authkey" { type = string }
variable "airkorea_service_key" { type = string }
variable "emp_api_key" { type = string }
variable "rds_db_password" { type = string }
variable "onprem_ip" { type = string }
variable "primary_health_check_id" { 
  type = string 
  default = ""
}
variable "alb_dns_name" {
  type = string
}

variable "alb_zone_id" {
  type = string
}

variable "default_model" {
  type    = string
  default = "llama3.1:8b"
}

variable "use_cloudfront_only" {
  type    = bool
  default = false
}
