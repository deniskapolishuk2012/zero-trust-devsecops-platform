variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "location" {
  description = "Primary Azure region for platform resources"
  type        = string
  default     = "westeurope"
}

variable "monitoring_location" {
  description = "Region for Log Analytics workspace, Defender, and Sentinel"
  type        = string
  default     = "westeurope"
}

variable "environment" {
  type    = string
  default = "lab"
}

variable "project" {
  type    = string
  default = "zero-trust-devsecops-platform"
}

variable "owner" {
  type    = string
  default = "Denis"
}

variable "acr_name_suffix" {
  description = "Short unique suffix for the ACR name (globally unique, alphanumeric only)"
  type        = string
}

# --- Sprint 2: GitHub OIDC federation ---
variable "github_org" {
  description = "GitHub organization or user that owns the platform repo"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (without the org prefix)"
  type        = string
}

variable "github_branch" {
  description = "Branch trusted with deploy-capable OIDC credentials"
  type        = string
  default     = "master"
}


# --- AKS / Azure AD RBAC ---
variable "aks_admin_group_object_ids" {
  description = "Entra ID group object IDs granted cluster-admin via Azure RBAC (cluster has local accounts disabled)"
  type        = list(string)
  default     = []
}

# --- Sprint 2: workload identity demo binding ---
variable "workload_namespace" {
  description = "Namespace of the demo workload that reads secrets via workload identity"
  type        = string
  default     = "workload-demo"
}

variable "workload_service_account_name" {
  description = "ServiceAccount of the demo workload bound to the federated identity"
  type        = string
  default     = "workload-demo-sa"
}

# --- Sprint 3/4: supply-chain verification ---
variable "cosign_public_key" {
  description = "PEM-encoded Cosign public key for Kyverno image-signature verification. Empty disables the policy until signing is wired up."
  type        = string
  default     = ""
  sensitive   = true
}
