variable "environment" { type = string }
variable "aws_region" { type = string }
variable "project_name" { type = string }

# RDS
variable "db_instance_class" { type = string }
variable "rds_db_password" { type = string }
variable "onprem_db_password" { type = string }
variable "db_allocated_storage" { type = number }
variable "postgres_version" { type = string }

# DMS
variable "onprem_db_tailscale_ip" { type = string }
variable "dms_instance_class" { type = string }

# Tailscale
variable "tailscale_api_key" { type = string }
variable "tailnet" { type = string }

# Bridge
variable "bridge_ami_id" { type = string }
variable "bridge_instance_type" { type = string }
