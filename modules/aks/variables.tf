variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "aks_subnet_id" {
  type = string
}

variable "acr_id" {
  description = "ACR resource ID — kubelet identity is granted AcrPull on it"
  type        = string
}

variable "kubernetes_version" {
  description = "Leave null to let Azure pick the default supported version"
  type        = string
  default     = null
}

variable "admin_group_object_ids" {
  description = "Entra ID group object IDs granted cluster-admin via Azure RBAC (no local accounts)"
  type        = list(string)
  default     = []
}

variable "system_node_vm_size" {
  type    = string
  default = "Standard_D2s_v3"
}

variable "system_node_count" {
  type    = number
  default = 1
}

variable "user_node_vm_size" {
  type    = string
  default = "Standard_D2s_v3"
}

variable "user_node_min_count" {
  type    = number
  default = 1
}

variable "user_node_max_count" {
  type    = number
  default = 3
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
