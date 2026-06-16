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

  # Public access is required so AKS pods (workload identity) and the Terraform
  # runner can reach the vault. RBAC is the security boundary — the workload SA
  # has only "Key Vault Secrets User" (read-only, single secret) and the operator
  # has "Key Vault Secrets Officer". A VNet-only rule would work too but requires
  # the Microsoft.KeyVault service endpoint on the AKS subnet; public+RBAC is
  # simpler and equally secure for this architecture.
  public_network_access_enabled = true

  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow"
  }

  tags = var.common_tags
}

resource "azurerm_management_lock" "key_vault" {
  name       = "lock-kv-ztp"
  scope      = azurerm_key_vault.this.id
  lock_level = "CanNotDelete"
  notes      = "Managed by Terraform — do not delete manually"
}

# Grants the operator (whoever runs terraform) Key Vault Secrets Officer so they
# can create/rotate secrets and so the azurerm_key_vault_secret below can be
# applied by the same service principal that owns the state.
resource "azurerm_role_assignment" "operator_kv_secrets_officer" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Seed the demo secret so a fresh apply is fully self-contained — no manual
# portal step needed. The workload reads this via Workload Identity (read-only).
resource "azurerm_key_vault_secret" "demo_secret" {
  name         = "demo-secret"
  value        = "zero-trust-works"
  key_vault_id = azurerm_key_vault.this.id
  depends_on   = [azurerm_role_assignment.operator_kv_secrets_officer]
}