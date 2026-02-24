variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "onprem_cidrs" {
  type = list(string)
}

variable "allow_icmp" {
  type    = bool
  default = true
}

variable "allow_ssh" {
  type    = bool
  default = true
}

