output "rg_platform_name" {
  value = module.governance.rg_platform_name
}

output "rg_security_name" {
  value = module.governance.rg_security_name
}

output "vnet_id" {
  value = module.networking.vnet_id
}

output "acr_login_server" {
  value = module.acr.acr_login_server
}

output "key_vault_uri" {
  value = module.key_vault.key_vault_uri
}

output "aks_cluster_name" {
  value = module.aks.cluster_name
}

output "aks_oidc_issuer_url" {
  value = module.aks.oidc_issuer_url
}

output "github_actions_client_id" {
  description = "Set as AZURE_CLIENT_ID in the GitHub Actions workflow — no client secret needed (OIDC federation)"
  value       = module.github_oidc.application_client_id
}

output "workload_identity_client_id" {
  description = "Annotate the workload's ServiceAccount with azure.workload.identity/client-id = this value"
  value       = module.workload_identity.client_id
}

output "law_workspace_id" {
  value = module.monitoring.law_workspace_id
}

output "sentinel_workspace_id" {
  value = module.sentinel.sentinel_workspace_id
}
