variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "private_route_table_ids" {
  type = list(string)
}

variable "onprem_public_ip" {
  type = string
}

variable "onprem_cidr" {
  type = string
}

