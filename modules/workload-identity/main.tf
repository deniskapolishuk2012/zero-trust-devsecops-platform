# Pod-level Zero Trust: a workload's ServiceAccount token (signed by the AKS OIDC
# issuer) is exchanged directly for an Entra ID token — no node-level identity
# sharing, no stored secrets, no Key Vault CSI driver polling with static creds.
resource "azurerm_user_assigned_identity" "this" {
  name                = "id-wi-${var.namespace}-${var.service_account_name}-ztp"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.common_tags
}

resource "azurerm_federated_identity_credential" "this" {
  name                = "fic-${var.namespace}-${var.service_account_name}"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.this.id
  issuer              = var.oidc_issuer_url
  subject             = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
  audience            = ["api://AzureADTokenExchange"]
}

# Read-only: the workload can fetch secret values but cannot list, create, or manage them
resource "azurerm_role_assignment" "key_vault_secrets_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.this.principal_id
}
