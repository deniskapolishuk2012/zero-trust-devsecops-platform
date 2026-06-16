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

  public_network_access_enabled = false

  network_acls {
    bypass                     = "AzureServices"
    default_action             = "Deny"
    ip_rules                   = []
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

# Grants the operator (whoever runs terraform) Key Vault Secrets Officer on this
# vault so they can create/rotate demo-secret via the Azure portal without opening
# public network access — the portal backend is a trusted AzureService and bypasses
# the network ACL (bypass = "AzureServices" above), so no ip_rules hack is needed.
resource "azurerm_role_assignment" "operator_kv_secrets_officer" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}