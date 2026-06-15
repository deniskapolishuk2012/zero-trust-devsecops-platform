variable "github_org" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "github_branch" {
  description = "Branch allowed to assume the deploy identity via OIDC"
  type        = string
  default     = "main"
}

variable "acr_id" {
  description = "ACR resource ID — CI/CD identity is granted AcrPush to publish images"
  type        = string
}

variable "aks_cluster_id" {
  description = "AKS cluster resource ID — CI/CD identity is granted scoped Kubernetes RBAC roles to deploy"
  type        = string
}
