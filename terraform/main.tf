# --- Sprint 1: foundation ---

module "governance" {
  source = "../modules/governance"

  location    = var.location
  common_tags = local.common_tags
}

module "networking" {
  source = "../modules/networking"

  location            = var.location
  resource_group_name = module.governance.rg_platform_name
  common_tags         = local.common_tags

  depends_on = [module.governance]
}

module "acr" {
  source = "../modules/acr"

  location            = var.location
  resource_group_name = module.governance.rg_platform_name
  name_suffix         = var.acr_name_suffix
  common_tags         = local.common_tags

  depends_on = [module.governance]
}

module "key_vault" {
  source = "../modules/key-vault"

  location            = var.location
  resource_group_name = module.governance.rg_security_name
  aks_subnet_id       = module.networking.aks_subnet_id
  common_tags         = local.common_tags

  depends_on = [module.networking]
}

module "aks" {
  source = "../modules/aks"

  location               = var.location
  resource_group_name    = module.governance.rg_platform_name
  aks_subnet_id          = module.networking.aks_subnet_id
  acr_id                 = module.acr.acr_id
  admin_group_object_ids = var.aks_admin_group_object_ids
  common_tags            = local.common_tags

  depends_on = [module.networking, module.acr]
}

# --- Sprint 2: OIDC federation + workload identity ---

module "github_oidc" {
  source = "../modules/github-oidc"

  github_org     = var.github_org
  github_repo    = var.github_repo
  github_branch  = var.github_branch
  acr_id         = module.acr.acr_id
  aks_cluster_id = module.aks.cluster_id

  depends_on = [module.aks]
}

module "workload_identity" {
  source = "../modules/workload-identity"

  location             = var.location
  resource_group_name  = module.governance.rg_platform_name
  oidc_issuer_url      = module.aks.oidc_issuer_url
  namespace            = var.workload_namespace
  service_account_name = var.workload_service_account_name
  key_vault_id         = module.key_vault.key_vault_id
  common_tags          = local.common_tags

  depends_on = [module.aks, module.key_vault]
}

# --- Sprint 5: monitoring, Defender, Sentinel ---

module "monitoring" {
  source = "../modules/monitoring"

  location            = var.monitoring_location
  resource_group_name = module.governance.rg_security_name
  key_vault_id        = module.key_vault.key_vault_id
  acr_id              = module.acr.acr_id
  aks_cluster_id      = module.aks.cluster_id
  common_tags         = local.common_tags

  depends_on = [module.aks, module.acr, module.key_vault]
}

module "defender" {
  source = "../modules/defender"

  log_analytics_workspace_id = module.monitoring.law_id

  depends_on = [module.monitoring]
}

module "sentinel" {
  source = "../modules/sentinel"

  log_analytics_workspace_id = module.monitoring.law_id

  depends_on = [module.monitoring]
}

# --- Sprint 4: in-cluster admission control ---

module "kyverno" {
  source = "../modules/kyverno"

  acr_login_server  = module.acr.acr_login_server
  cosign_public_key = var.cosign_public_key

  depends_on = [module.aks]
}

# --- Sprint 6: CIS compliance as code ---

module "kube_bench" {
  source = "../modules/kube-bench"

  depends_on = [module.aks]
}
