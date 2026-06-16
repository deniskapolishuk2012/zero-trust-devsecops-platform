# Premium SKU required for: private endpoints, content trust (Cosign-compatible),
# geo-replication, and the retention policy below.
resource "azurerm_container_registry" "this" {
  name                = "acr${var.name_suffix}ztp"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Premium"
  admin_enabled       = false

  public_network_access_enabled = true

  # Quarantine blocks all tag lookups until an image is manually released — cosign
  # sign and attest fail because they can't find the manifest by tag or digest.
  # Security scanning is enforced in the pipeline (Trivy step) before push, so
  # quarantine adds no extra protection and breaks the supply chain.
  quarantine_policy_enabled = false
  trust_policy {
    enabled = true
  }
  retention_policy {
    enabled = true
    days    = 30
  }

  tags = var.common_tags
}

resource "azurerm_management_lock" "acr" {
  name       = "lock-acr-ztp"
  scope      = azurerm_container_registry.this.id
  lock_level = "CanNotDelete"
  notes      = "Managed by Terraform — do not delete manually"
}

# AKS kubelet identity gets AcrPull — wired in root module once the cluster exists,
# see azurerm_role_assignment.aks_acr_pull in modules/aks