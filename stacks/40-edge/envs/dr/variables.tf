variable "environment" { type = string }
variable "region" { type = string }
variable "domain_name" { type = string }
variable "primary_target_domain" { type = string }
variable "cluster_oidc_provider_arn" { type = string }
variable "worker_image_url" { type = string }
variable "alarm_email" { type = string }
