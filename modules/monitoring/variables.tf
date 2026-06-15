variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "key_vault_id" {
  type = string
}

variable "acr_id" {
  type = string
}

variable "aks_cluster_id" {
  type = string
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
