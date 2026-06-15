# Demo Checklist — "create → screenshot → destroy"

Run `scripts/powershell/Start-DemoEnvironment.ps1`, then work through this list.
It's ordered so the **time-sensitive item is triggered first** (Sentinel's
`ZTP-Privileged-Container-Blocked` rule runs every 5 minutes — `PT5M`), and the
quick portal screenshots fill that waiting time. When you're done, run
`scripts/powershell/Stop-DemoEnvironment.ps1`.

Total wall-clock budget: ~15-20 minutes of "screenshot time" after the ~20-40 min
`terraform apply`. The two PT1H Sentinel rules (`ZTP-Pod-Exec-Attempts`,
`ZTP-ACR-Auth-Failures`) won't realistically fire within a single short session —
screenshot their *configuration* (rule definition + MITRE mapping) instead of
waiting for an incident.

## 0. Immediate — already done by the start script

- [ ] **Kyverno denial** — terminal output from `kubectl apply -f demo/privileged-pod-attempt.yaml`.
      Shows the `admission webhook ... denied the request` message with the three
      violated rules (privileged, host namespaces, hostPath).
- [ ] **PolicyReport** — run:
      ```
      kubectl get policyreport -n workload-demo -o wide
      ```
      Shows the same denial recorded as a Kubernetes-native object.

## 1. Start the 5-minute clock, then do the portal screenshots below

The denied admission request needs to land in `kube-audit-admin` →
Log Analytics → trigger the scheduled rule. Budget **5-10 minutes** from when
step 0 ran. While waiting:

- [ ] **AKS overview** — portal → `rg-platform-ztp` → `aks-ztp` → Overview.
      Then **Settings → Cluster configuration**: show "Local accounts" =
      Disabled, Azure RBAC = Enabled, AAD admin group set.
- [ ] **AKS OIDC issuer** — same blade, "Cluster configuration" — show the
      OIDC issuer URL and Workload Identity = Enabled.
- [ ] **ACR** — portal → `rg-platform-ztp` → ACR resource → Overview: SKU =
      Premium, Public network access = Disabled. Then **Policies**: Quarantine
      + Retention enabled.
- [ ] **Key Vault RBAC** — portal → `rg-security-ztp` → Key Vault →
      **Access control (IAM) → Role assignments**: the workload-identity
      user-assigned identity has **Key Vault Secrets User** — nothing more.
- [ ] **Entra ID federated credentials (no secrets)** — portal → Microsoft
      Entra ID → App registrations → `github-actions-ztp` →
      **Certificates & secrets → Federated credentials**: shows the
      `repo:.../ref:refs/heads/main` and `repo:.../pull_request` subjects, and
      that the "Client secrets" tab is empty.
- [ ] **Defender for Containers** — portal → Microsoft Defender for Cloud →
      Environment settings → your subscription → **Defender plans**:
      Containers = On.
- [ ] **kube-bench CronJob** — run:
      ```
      kubectl get cronjob -n kube-bench
      ```
      Shows the scheduled CIS `aks-1.0` benchmark job (Sprint 6 — compliance as
      code, doesn't need to have run yet).
- [ ] **Sentinel rules configuration** — portal → Microsoft Sentinel →
      `law-ztp` → **Analytics**: all three `ZTP-*` rules listed, enabled. Open
      `ZTP-Privileged-Container-Blocked` → show **Tactics/Techniques** =
      Privilege Escalation/Defense Evasion, T1610/T1611.

## 2. Confirm the audit trail (works immediately, no waiting)

- [ ] **Log Analytics — manual query** — portal → `law-ztp` → **Logs**, run:
      ```kql
      AzureDiagnostics
      | where Category == "kube-audit-admin"
      | extend Verb = tostring(parse_json(log_s).verb)
      | extend RequestURI = tostring(parse_json(log_s).requestURI)
      | extend StatusCode = toint(parse_json(log_s).responseStatus.code)
      | extend StatusMessage = tostring(parse_json(log_s).responseStatus.message)
      | where Verb == "create" and RequestURI has "/pods" and StatusCode == 400
      | where StatusMessage has "admission webhook"
      | project TimeGenerated, RequestURI, StatusMessage
      | order by TimeGenerated desc
      ```
      This is the row Sentinel's rule is watching for — screenshot it as proof
      the data pipeline works even before the incident appears.

## 3. The headline screenshot — Sentinel incident

- [ ] **Sentinel incident** — portal → Microsoft Sentinel → `law-ztp` →
      **Incidents**. Once `ZTP-Privileged-Container-Blocked` has run (check
      "Last run" on the rule), an incident with Severity = High and
      Tactics = Privilege Escalation / Defense Evasion should appear. Open it
      and screenshot the incident details pane (entities, MITRE tags, linked
      alert).
      - If nothing's there after 10 minutes: portal → the rule → **"Run query
        now"** (or open Logs and run the rule's query manually from
        `modules/sentinel/main.tf`) to confirm the query itself matches —
        scheduling delay vs. a real problem.

## 4. Teardown

- [ ] Run `scripts/powershell/Stop-DemoEnvironment.ps1`
- [ ] Confirm in the portal that `rg-platform-ztp` and `rg-security-ztp` are gone
