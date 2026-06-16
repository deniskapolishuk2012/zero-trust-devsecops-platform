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

variable "operator_ip" {
  description = "Your current public IP (e.g. from curl ifconfig.me) — added to Key Vault ip_rules so terraform can create the demo secret. Remove after the session."
  type        = string
  default     = ""
}

variable "demo_secret_value" {
  description = "Value to store in Key Vault as 'demo-secret' — proves the workload-identity chain end to end"
  type        = string
  default     = "zero-trust-works"
  sensitive   = true
}