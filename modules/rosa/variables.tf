variable "cluster_name" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "worker_node_count" {
  type    = number
  default = 2
}
