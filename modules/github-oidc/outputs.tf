output "application_client_id" {
  description = "Set as AZURE_CLIENT_ID in the GitHub Actions workflow (azure/login@v2 with no client-secret)"
  value       = azuread_application.github_actions.client_id
}

output "service_principal_object_id" {
  value = azuread_service_principal.github_actions.object_id
}

output "application_object_id" {
  value = azuread_application.github_actions.object_id
}
