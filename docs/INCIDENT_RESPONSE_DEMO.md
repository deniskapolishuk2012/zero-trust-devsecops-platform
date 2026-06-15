# Incident Response Demo — Privileged Container Attempt

Sprint 7 walkthrough: simulate an attacker trying to break out of a container,
watch the platform's layered defenses catch it, and trace the resulting incident
back to a MITRE ATT&CK technique. Everything referenced here is already wired up
by Terraform (`modules/kyverno`, `modules/monitoring`, `modules/sentinel`) — this
document is the *runbook*, not new infrastructure.

## Scenario

An attacker who has obtained limited access to the cluster (e.g. through a
compromised CI token or an exposed `kubectl` context) attempts to deploy a pod
that:
- runs as `privileged: true` with `SYS_ADMIN`
- mounts the host's root filesystem (`hostPath: /`)
- shares the host's PID and network namespaces

This is the canonical "container escape" pattern — if it succeeds, the attacker
effectively has root on the underlying node.

## Step 1 — Trigger the attempt

```bash
kubectl apply -f demo/privileged-pod-attempt.yaml
```

## Step 2 — Observe the block (Kyverno, Sprint 4)

The request never reaches the scheduler. The API server's response comes straight
back from Kyverno's admission webhook, enforcing the baseline Pod Security
"restricted" policy installed by `modules/kyverno`:

```
Error from server: error when creating "demo/privileged-pod-attempt.yaml":
admission webhook "validate.kyverno.svc-fail" denied the request:

policy Pod/workload-demo/attacker-privileged-probe for resource violation:

require-run-as-non-root:
  autogen-check-for-privileged: 'validation error: Privileged mode is not allowed.
  rule autogen-check-for-privileged failed at path /spec/containers/0/securityContext/privileged/'
disallow-host-namespaces:
  autogen-host-namespaces: 'validation error: Sharing the host namespaces is not
  allowed. rule autogen-host-namespaces failed at path /spec/hostPID/'
disallow-host-path:
  autogen-host-path: 'validation error: HostPath volumes are not allowed.
  rule autogen-host-path failed at path /spec/volumes/0/hostPath/'
```

You can also see the denial recorded as a `PolicyReport` in-cluster:

```bash
kubectl get policyreport -n workload-demo -o wide
```

## Step 3 — Trace the audit trail (Monitoring, Sprint 5)

The denied admission request is captured by the AKS `kube-audit-admin` diagnostic
category and shipped to the `law-ztp` Log Analytics workspace
(`modules/monitoring`):

```kql
AzureDiagnostics
| where Category == "kube-audit-admin"
| extend Verb = tostring(parse_json(log_s).verb)
| extend RequestURI = tostring(parse_json(log_s).requestURI)
| extend StatusCode = toint(parse_json(log_s).responseStatus.code)
| extend StatusMessage = tostring(parse_json(log_s).responseStatus.message)
| extend User = tostring(parse_json(log_s).user.username)
| where Verb == "create" and RequestURI has "/pods" and StatusCode == 403
| project TimeGenerated, User, RequestURI, StatusMessage
| order by TimeGenerated desc
```

## Step 4 — Watch the incident appear (Sentinel, Sprint 5)

The scheduled analytics rule **`ZTP-Privileged-Container-Blocked`**
(`modules/sentinel`) runs this exact query every 5 minutes. A hit raises an
incident in Microsoft Sentinel with:

- **Severity:** High
- **Tactics:** Privilege Escalation, Defense Evasion
- **Techniques:** T1610 (Deploy Container), T1611 (Escape to Host)

Open **Sentinel → Incidents** and confirm the new incident references the same
`User` / `RequestURI` / `TimeGenerated` you saw in Step 3 — that's the chain from
"attacker action" to "actionable alert" closing end to end.

## Step 5 — Triage and respond

1. Identify the principal in `User` — was it a human, a CI identity, or a
   workload identity? Cross-reference against `modules/github-oidc` /
   `modules/workload-identity` role assignments — does this principal *need*
   `pods/create` at all?
2. If the identity is a CI/CD principal: rotate nothing (there's no static secret
   to rotate — that's the point of OIDC federation), but review and tighten its
   `azurerm_role_assignment` scope in `modules/github-oidc`.
3. If the identity is a compromised user account: suspend it in Entra ID and pull
   `SigninLogs` for the same time window to scope the blast radius.
4. Close the loop: `kubectl get policyreport -A` for any other policy violations
   in the same time window — a single probe is rarely the whole story.

## MITRE ATT&CK mapping reference

| Sentinel rule | Technique | Tactic | What it actually catches |
|---|---|---|---|
| `ZTP-Privileged-Container-Blocked` | T1610 — Deploy Container | Privilege Escalation | Attempted privileged/host-mounted pod creation, denied at admission |
| `ZTP-Privileged-Container-Blocked` | T1611 — Escape to Host | Defense Evasion | `hostPID`/`hostNetwork`/`hostPath` combinations aimed at breaking the container boundary |
| `ZTP-Pod-Exec-Attempts` | T1609 — Container Administration Command | Execution, Lateral Movement | Repeated `kubectl exec` into running pods — common post-compromise reconnaissance |
| `ZTP-ACR-Auth-Failures` | T1110 — Brute Force | Credential Access | Repeated failed registry logins — credential-stuffing against ACR |
| `ZTP-KeyVault-Secret-Enumeration` | T1552 — Unsecured Credentials | Credential Access | A single caller reading an unusually high number of Key Vault secrets within an hour |

## Why this demo is the right one to lead with

It exercises every layer the platform built, in order: **identity** (who could
even attempt this), **admission control** (Kyverno stops it before it runs),
**audit** (the attempt is logged regardless of outcome), and **detection**
(Sentinel turns the log line into an incident with a MITRE citation). A reviewer
watching this end to end sees Zero Trust as a working system, not a slide.
