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

  lifecycle {
    prevent_destroy = true
  }

  tags = var.common_tags
}

resource "azurerm_management_lock" "key_vault" {
  name       = "lock-kv-ztp"
  scope      = azurerm_key_vault.this.id
  lock_level = "CanNotDelete"
  notes      = "Managed by Terraform — do not delete manually"
}