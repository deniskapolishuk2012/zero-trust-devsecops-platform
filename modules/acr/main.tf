# Premium SKU required for: private endpoints, content trust (Cosign-compatible),
# quarantine pattern (Trivy gate before an image is promotable), geo-replication
resource "azurerm_container_registry" "this" {
  name                = "acr${var.name_suffix}ztp"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Premium"
  admin_enabled       = false

  public_network_access_enabled = false

  quarantine_policy_enabled = true
  trust_policy {
    enabled = true
  }
  retention_policy {
    enabled = true
    days    = 30
  }

  tags = var.common_tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_management_lock" "acr" {
  name       = "lock-acr-ztp"
  scope      = azurerm_container_registry.this.id
  lock_level = "CanNotDelete"
  notes      = "Managed by Terraform — do not delete manually"
}

# AKS kubelet identity gets AcrPull — wired in root module once the cluster exists,
# see azurerm_role_assignment.aks_acr_pull in modules/aks