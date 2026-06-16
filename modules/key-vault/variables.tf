variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "aks_subnet_id" {
  description = "Subnet allowed to reach the vault over the network ACL (AKS pods using workload identity)"
  type        = string
}

variable "common_tags" {
  type    = map(string)
  default = {}
}

