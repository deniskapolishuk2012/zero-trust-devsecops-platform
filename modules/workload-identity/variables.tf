variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "oidc_issuer_url" {
  description = "AKS cluster OIDC issuer URL (modules.aks.oidc_issuer_url) — the trusted token issuer"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace the workload runs in"
  type        = string
}

variable "service_account_name" {
  description = "Kubernetes ServiceAccount the federated credential is bound to"
  type        = string
}

variable "key_vault_id" {
  description = "Key Vault resource ID — the identity is granted Key Vault Secrets User (read-only, no list/manage)"
  type        = string
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
