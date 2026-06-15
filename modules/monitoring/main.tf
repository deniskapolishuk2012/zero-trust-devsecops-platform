resource "azurerm_log_analytics_workspace" "this" {
  name                = "law-ztp"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 90
  tags                = var.common_tags
}

resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  name                       = "diag-kv-ztp"
  target_resource_id         = var.key_vault_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category_group = "audit"
  }
}

resource "azurerm_monitor_diagnostic_setting" "acr" {
  name                       = "diag-acr-ztp"
  target_resource_id         = var.acr_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category_group = "audit"
  }
}

# kube-audit-admin + guard feed the Sentinel rules in modules/sentinel: privileged
# pod creation, RBAC changes, and Entra ID auth decisions at the API server (Sprint 5)
resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "diag-aks-ztp"
  target_resource_id         = var.aks_cluster_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category = "kube-audit-admin"
  }

  enabled_log {
    category = "guard"
  }

  enabled_log {
    category = "kube-controller-manager"
  }
}
