variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "environment" {
  description = "환경 이름"
  type        = string
}

variable "subnet_ids" {
  type    = list(string)
  default = []
}
