data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_key_vault" "this" {
  name                = "kv-ztp-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  enable_rbac_authorization       = true
  purge_protection_enabled        = true
  soft_delete_retention_days      = 90
  enabled_for_disk_encryption     = false
  enabled_for_deployment          = false
  enabled_for_template_deployment = false

  public_network_access_enabled = var.operator_ip != "" ? true : false

  network_acls {
    bypass                     = "AzureServices"
    default_action             = "Deny"
    ip_rules                   = var.operator_ip != "" ? ["${var.operator_ip}/32"] : []
    virtual_network_subnet_ids = [var.aks_subnet_id]
  }

  tags = var.common_tags
}

resource "azurerm_management_lock" "key_vault" {
  name       = "lock-kv-ztp"
  scope      = azurerm_key_vault.this.id
  lock_level = "CanNotDelete"
  notes      = "Managed by Terraform — do not delete manually"
}

# The workload-identity demo reads this secret to prove the pod-identity chain:
# ServiceAccount token → Entra ID token exchange → Key Vault Secrets User read.
# Requires operator_ip to be set in tfvars so Terraform can reach the data plane.
resource "azurerm_key_vault_secret" "demo" {
  name         = "demo-secret"
  value        = var.demo_secret_value
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [azurerm_key_vault.this]
}