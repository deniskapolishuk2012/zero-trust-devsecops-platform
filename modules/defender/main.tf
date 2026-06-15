data "azurerm_subscription" "current" {}

# Subscription-wide setting — there is exactly one per subscription, so this module
# should only be instantiated once even if other workloads share the subscription.
resource "azurerm_security_center_subscription_pricing" "containers" {
  tier          = "Standard"
  resource_type = "Containers"
}

resource "azurerm_security_center_workspace" "this" {
  scope        = data.azurerm_subscription.current.id
  workspace_id = var.log_analytics_workspace_id
}
