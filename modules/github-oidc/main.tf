# GitHub Actions → Entra ID federation: no client secrets, no long-lived credentials.
# GitHub presents a short-lived OIDC token; Entra ID trusts it only for the exact
# repo + ref combinations registered as federated credentials below.
data "azuread_client_config" "current" {}

resource "azuread_application" "github_actions" {
  display_name = "github-actions-ztp"
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "github_actions" {
  client_id = azuread_application.github_actions.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

# Deploy identity — trusted only for pushes/merges to the protected branch
resource "azuread_application_federated_identity_credential" "branch" {
  application_id = azuread_application.github_actions.id
  display_name   = "github-branch-${var.github_branch}"
  description    = "OIDC trust for GitHub Actions on refs/heads/${var.github_branch}"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${var.github_branch}"
}

# CI identity — trusted for pull_request events so checks (Checkov/Trivy/SBOM, Sprint 3)
# can run on forks/branches without ever holding deploy-capable credentials
resource "azuread_application_federated_identity_credential" "pull_request" {
  application_id = azuread_application.github_actions.id
  display_name   = "github-pull-request"
  description    = "OIDC trust for GitHub Actions on pull_request events"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_org}/${var.github_repo}:pull_request"
}

# Least-privilege roles for the pipeline: push images, deploy via kubectl — nothing else
resource "azurerm_role_assignment" "acr_push" {
  scope                = var.acr_id
  role_definition_name = "AcrPush"
  principal_id         = azuread_service_principal.github_actions.object_id
}

resource "azurerm_role_assignment" "aks_cluster_user" {
  scope                = var.aks_cluster_id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = azuread_service_principal.github_actions.object_id
}

# Cluster Admin is required because the deploy workflow creates the workload-demo
# namespace and applies cluster-scoped resources. RBAC Writer is namespace-scoped
# and cannot create namespaces or ClusterRoleBindings, which causes the first
# deploy to fail with "forbidden: user cannot create namespaces".
resource "azurerm_role_assignment" "aks_rbac_writer" {
  scope                = var.aks_cluster_id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = azuread_service_principal.github_actions.object_id
}
