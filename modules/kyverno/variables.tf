variable "kyverno_chart_version" {
  description = "Kyverno engine Helm chart version"
  type        = string
  default     = "3.2.6"
}

variable "kyverno_policies_chart_version" {
  description = "kyverno/kyverno-policies (baseline Pod Security Standards) chart version"
  type        = string
  default     = "3.2.6"
}

variable "acr_login_server" {
  description = "Only images from this registry are allowed to run / are eligible for signature verification"
  type        = string
}

variable "cosign_public_key" {
  description = "PEM-encoded Cosign public key used to verify image signatures. Leave empty to skip the verifyImages policy until signing (Sprint 3) is wired up."
  type        = string
  default     = ""
  sensitive   = true
}
