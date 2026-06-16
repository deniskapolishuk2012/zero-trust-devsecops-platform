resource "azurerm_sentinel_log_analytics_workspace_onboarding" "this" {
  workspace_id = var.log_analytics_workspace_id
}

# Sentinel backend needs ~2 minutes after onboarding before it can validate
# KQL queries in alert rules — without this wait, rule creation fails with
# "workspace could not be found" even though onboarding succeeded.
resource "time_sleep" "sentinel_ready" {
  create_duration = "120s"
  depends_on      = [azurerm_sentinel_log_analytics_workspace_onboarding.this]
}

# Sprint 7 demo trigger: an attempt to deploy a privileged container is rejected by
# the API server (Kyverno admission webhook returns 403) — this rule turns that
# kube-audit-admin entry into an incident. Maps to MITRE ATT&CK T1610 (Deploy Container)
# and T1611 (Escape to Host).
resource "azurerm_sentinel_alert_rule_scheduled" "privileged_container_blocked" {
  name                       = "ZTP-Privileged-Container-Blocked"
  log_analytics_workspace_id = azurerm_sentinel_log_analytics_workspace_onboarding.this.workspace_id
  display_name               = "ZTP-Privileged-Container-Blocked"
  description                = "A pod creation request was denied by an admission controller (Kyverno) for violating the no-privileged-containers policy"
  severity                   = "High"
  enabled                    = true

  query = <<-EOT
    AzureDiagnostics
    | where Category == "kube-audit-admin"
    | extend LogJson = parse_json(tostring(column_ifexists("log_s", "{}")))
    | extend Verb = tostring(LogJson.verb)
    | extend RequestURI = tostring(LogJson.requestURI)
    | extend StatusCode = toint(LogJson.responseStatus.code)
    | extend StatusMessage = tostring(LogJson.responseStatus.message)
    | extend User = tostring(LogJson.user.username)
    | where Verb == "create" and RequestURI has "/pods"
    | where StatusCode == 400
    | where StatusMessage has "admission webhook" and StatusMessage has_any ("privileged", "kyverno", "policy")
    | project TimeGenerated, User, RequestURI, StatusMessage
  EOT

  query_frequency = "PT5M"
  query_period    = "PT5M"

  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  tactics    = ["PrivilegeEscalation", "DefenseEvasion"]
  techniques = ["T1610", "T1611"]

  depends_on = [time_sleep.sentinel_ready]
}

# Interactive exec into a running pod is a common post-compromise step (credential
# theft, lateral movement). Repeated attempts from the same identity are suspicious.
# Maps to MITRE ATT&CK T1609 (Container Administration Command).
resource "azurerm_sentinel_alert_rule_scheduled" "pod_exec_attempts" {
  name                       = "ZTP-Pod-Exec-Attempts"
  log_analytics_workspace_id = azurerm_sentinel_log_analytics_workspace_onboarding.this.workspace_id
  display_name               = "ZTP-Pod-Exec-Attempts"
  description                = "A user invoked 'kubectl exec' against pods more than expected within an hour"
  severity                   = "Medium"
  enabled                    = true

  query = <<-EOT
    AzureDiagnostics
    | where Category == "kube-audit-admin"
    | extend LogJson = parse_json(tostring(column_ifexists("log_s", "{}")))
    | extend Verb = tostring(LogJson.verb)
    | extend RequestURI = tostring(LogJson.requestURI)
    | extend User = tostring(LogJson.user.username)
    | where Verb == "create" and RequestURI has "/exec"
    | summarize ExecCount = count() by User, bin(TimeGenerated, 1h)
    | where ExecCount > 3
  EOT

  query_frequency = "PT1H"
  query_period    = "PT1H"

  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  tactics    = ["Execution", "LateralMovement"]
  techniques = ["T1609"]

  depends_on = [time_sleep.sentinel_ready]
}

# Repeated failed registry logins look like credential stuffing against ACR — the
# same pattern as brute-forcing any other credential store. Maps to MITRE ATT&CK
# T1110 (Brute Force).
resource "azurerm_sentinel_alert_rule_scheduled" "acr_auth_failures" {
  name                       = "ZTP-ACR-Auth-Failures"
  log_analytics_workspace_id = azurerm_sentinel_log_analytics_workspace_onboarding.this.workspace_id
  display_name               = "ZTP-ACR-Auth-Failures"
  description                = "Repeated failed authentication attempts against the container registry from the same caller"
  severity                   = "Medium"
  enabled                    = true

  query = <<-EOT
    AzureDiagnostics
    | where ResourceProvider == "MICROSOFT.CONTAINERREGISTRY"
    | where OperationName has "Login"
    | where ResultType !in ("Succeeded", "Success")
    | extend Caller = tostring(column_ifexists("CallerIpAddress", "unknown"))
    | summarize FailureCount = count() by Caller, bin(TimeGenerated, 1h)
    | where FailureCount > 3
  EOT

  query_frequency = "PT1H"
  query_period    = "PT1H"

  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  tactics    = ["CredentialAccess"]
  techniques = ["T1110"]

  depends_on = [time_sleep.sentinel_ready]
}

# A burst of secret reads from a single caller looks like enumeration — either
# a compromised identity pulling everything it can reach, or a workload
# identity being used outside its expected pattern. Maps to MITRE ATT&CK
# T1552 (Unsecured Credentials).
resource "azurerm_sentinel_alert_rule_scheduled" "key_vault_secret_enumeration" {
  name                       = "ZTP-KeyVault-Secret-Enumeration"
  log_analytics_workspace_id = azurerm_sentinel_log_analytics_workspace_onboarding.this.workspace_id
  display_name               = "ZTP-KeyVault-Secret-Enumeration"
  description                = "A single caller read an unusually high number of Key Vault secrets within an hour"
  severity                   = "Medium"
  enabled                    = true

  query = <<-EOT
    AzureDiagnostics
    | where ResourceProvider == "MICROSOFT.KEYVAULT"
    | where OperationName == "SecretGet"
    | where ResultType == "Success"
    | summarize SecretGetCount = dcount(id_s), Caller = any(CallerIPAddress) by identity_claim_appid_g, bin(TimeGenerated, 1h)
    | where SecretGetCount > 5
  EOT

  query_frequency = "PT1H"
  query_period    = "PT1H"

  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  tactics    = ["CredentialAccess"]
  techniques = ["T1552"]

  depends_on = [time_sleep.sentinel_ready]
}
