# Zero Trust cluster: Entra ID + Azure RBAC only (no local accounts), OIDC issuer +
# workload identity for pod-level federated credentials (Sprint 2), Azure CNI with
# network policy enforced so Kyverno/NetworkPolicy objects (Sprint 4) actually take effect.
resource "azurerm_kubernetes_cluster" "this" {
  name                = "aks-ztp"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "aks-ztp"
  kubernetes_version  = var.kubernetes_version
  sku_tier            = "Standard"

  local_account_disabled = true

  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  azure_policy_enabled      = true

  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_node_vm_size
    node_count                   = var.system_node_count
    vnet_subnet_id               = var.aks_subnet_id
    only_critical_addons_enabled = true
  }

  identity {
    type = "SystemAssigned"
  }

  azure_active_directory_role_based_access_control {
    managed                = true
    azure_rbac_enabled     = true
    admin_group_object_ids = var.admin_group_object_ids
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
    outbound_type  = "loadBalancer"
  }

  tags = var.common_tags

  lifecycle {
    ignore_changes = [kubernetes_version]
  }
}

# Separate user pool so workloads never land on system/critical-addon nodes
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = var.user_node_vm_size
  vnet_subnet_id        = var.aks_subnet_id
  mode                  = "User"
  enable_auto_scaling   = true
  min_count             = var.user_node_min_count
  max_count             = var.user_node_max_count

  tags = var.common_tags
}

# Kubelet identity pulls images from ACR — least privilege (AcrPull only, no admin user)
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                            = var.acr_id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}
