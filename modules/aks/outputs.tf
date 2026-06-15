output "cluster_id" {
  value = azurerm_kubernetes_cluster.this.id
}

output "cluster_name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "oidc_issuer_url" {
  description = "Used as the issuer for federated identity credentials (modules/workload-identity, modules/github-oidc)"
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "kubelet_identity_object_id" {
  value = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

output "cluster_identity_principal_id" {
  value = azurerm_kubernetes_cluster.this.identity[0].principal_id
}

output "kube_config_raw" {
  value     = azurerm_kubernetes_cluster.this.kube_config_raw
  sensitive = true
}

output "kube_admin_config_raw" {
  value     = try(azurerm_kubernetes_cluster.this.kube_admin_config_raw, null)
  sensitive = true
}

output "host" {
  value     = azurerm_kubernetes_cluster.this.kube_config[0].host
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate
  sensitive = true
}
