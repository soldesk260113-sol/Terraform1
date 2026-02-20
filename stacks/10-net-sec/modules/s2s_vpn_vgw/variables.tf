variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "onprem_public_ip" {
  type = string
}

variable "onprem_cidr" {
  type = string
}

variable "cgw_bgp_asn" {
  type    = number
  default = 65000
}

variable "static_routes_only" {
  type    = bool
  default = true
}

variable "route_table_ids" {
  type        = list(string)
  description = "Route tables that should route onprem_cidr to VGW (usually private RTs)."
}

