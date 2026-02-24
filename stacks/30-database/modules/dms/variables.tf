variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "DMS 인스턴스가 위치할 Private 서브넷 리스트"
  type        = list(string)
}

variable "onprem_db_tailscale_ip" {
  description = "온프레미스 DB의 Tailscale IP"
  type        = string
}

variable "rds_endpoint" {
  description = "타겟 RDS 엔드포인트 주소"
  type        = string
}

variable "onprem_db_password" {
  description = "온프레미스 소스 DB 패스워드"
  type        = string
  sensitive   = true
}

variable "rds_db_password" {
  description = "RDS 타겟 DB 패스워드"
  type        = string
  sensitive   = true
}

variable "dms_instance_class" {
  description = "DMS 복제 인스턴스 사양"
  type        = string
  default     = "dms.t3.medium"
}
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "migration_type" {
  description = "DMS 마이구조 방식 (full-load, cdc, full-load-and-cdc)"
  type        = string
  default     = "full-load"
}
