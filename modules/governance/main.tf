resource "azurerm_resource_group" "platform" {
  name     = "rg-platform-ztp"
  location = var.location
  tags     = var.common_tags
}

resource "azurerm_resource_group" "security" {
  name     = "rg-security-ztp"
  location = var.location
  tags     = var.common_tags
}

resource "azurerm_management_lock" "platform" {
  name       = "lock-rg-platform"
  scope      = azurerm_resource_group.platform.id
  lock_level = "CanNotDelete"
  notes      = "Managed by Terraform"
}

resource "azurerm_management_lock" "security" {
  name       = "lock-rg-security"
  scope      = azurerm_resource_group.security.id
  lock_level = "CanNotDelete"
  notes      = "Managed by Terraform"
}