# ACR scoped token so Kyverno can pull manifests to verify cosign signatures.
# The built-in _repositories_pull scope map grants read access to all repositories.
data "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = var.acr_resource_group_name
}

resource "azurerm_container_registry_token" "kyverno_verify" {
  name                    = "kyverno-verify"
  container_registry_name = data.azurerm_container_registry.acr.name
  resource_group_name     = var.acr_resource_group_name
  scope_map_id            = "${data.azurerm_container_registry.acr.id}/scopeMaps/_repositories_pull"
}

resource "azurerm_container_registry_token_password" "kyverno_verify" {
  container_registry_token_id = azurerm_container_registry_token.kyverno_verify.id
  password1 {}
}

# Create the kyverno namespace first so the ACR credentials secret can be placed
# there before Helm installs the admission controller (which needs the secret to
# authenticate to ACR for image-signature verification via --imagePullSecrets).
resource "kubernetes_namespace" "kyverno" {
  metadata {
    name = "kyverno"
  }
}

resource "kubernetes_secret" "acr_kyverno_creds" {
  metadata {
    name      = "acr-kyverno-creds"
    namespace = kubernetes_namespace.kyverno.metadata[0].name
  }
  type = "kubernetes.io/dockerconfigjson"
  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        (var.acr_login_server) = {
          username = azurerm_container_registry_token.kyverno_verify.name
          password = azurerm_container_registry_token_password.kyverno_verify.password1[0].value
          auth = base64encode(
            "${azurerm_container_registry_token.kyverno_verify.name}:${azurerm_container_registry_token_password.kyverno_verify.password1[0].value}"
          )
        }
      }
    })
  }
}

# Admission control engine. The policies below are CRDs (ClusterPolicy) that only
# exist once this release is reconciled — every kubectl_manifest policy in this
# module depends_on it so a fresh cluster applies in the right order.
#
# kubectl_manifest (not the hashicorp/kubernetes kubernetes_manifest resource) is
# used deliberately: kubernetes_manifest needs to query the live cluster's OpenAPI
# schema at *plan* time, which is impossible on a first-ever apply where the AKS
# cluster (module.aks) doesn't exist yet. kubectl_manifest applies server-side
# without that plan-time dependency.
resource "helm_release" "kyverno" {
  name             = "kyverno"
  repository       = "https://kyverno.github.io/kyverno/"
  chart            = "kyverno"
  version          = var.kyverno_chart_version
  namespace        = "kyverno"
  create_namespace = false  # namespace created explicitly above so the secret exists first

  set {
    name  = "replicaCount"
    value = "1"
  }

  # PolicyExceptions are restricted to this namespace so only the kube-bench
  # CronJob (which legitimately needs hostPID + read-only hostPath mounts to
  # read node-level CIS config, see modules/kube-bench) can opt out of the
  # restricted Pod Security policies below.
  set {
    name  = "features.policyExceptions.enabled"
    value = "true"
  }

  set {
    name  = "features.policyExceptions.namespace"
    value = "kube-bench"
  }

  # Pass the ACR credentials secret to the admission controller so it can
  # authenticate to private ACR when verifying cosign image signatures.
  set {
    name  = "admissionController.extraArgs[0]"
    value = "--imagePullSecrets=acr-kyverno-creds"
  }

  depends_on = [kubernetes_secret.acr_kyverno_creds]
}

# Pre-create the workload-demo namespace so the deploy workflow doesn't need to
# and the Kyverno network-policy generator fires at namespace creation time
# (giving the workload a default-deny-ingress policy from day one).
resource "kubernetes_namespace" "workload_demo" {
  metadata {
    name = "workload-demo"
    labels = {
      "azure.workload.identity/use" = "true"
    }
  }
  depends_on = [helm_release.kyverno]
}

# Baseline Pod Security Standard "restricted" — covers no-privileged-containers,
# no host namespaces/paths, drop-all-capabilities, run-as-non-root, etc. in one chart
# instead of hand-writing two dozen ClusterPolicies (Sprint 4).
resource "helm_release" "kyverno_policies" {
  name       = "kyverno-policies"
  repository = "https://kyverno.github.io/kyverno/"
  chart      = "kyverno-policies"
  version    = var.kyverno_policies_chart_version
  namespace  = "kyverno"

  values = [yamlencode({
    podSecurityStandard     = "restricted"
    podSecuritySeverity     = "high"
    validationFailureAction = "Enforce"
  })]

  depends_on = [helm_release.kyverno]
}

# Owned here (rather than in modules/kube-bench) so the namespace, the
# restricted-policy enforcement, and its exception are all sequenced correctly:
# module.kube_bench depends_on module.kyverno (see terraform/main.tf), so this
# namespace + the PolicyException below exist before the kube-bench CronJob
# is ever applied.
resource "kubernetes_namespace" "kube_bench" {
  metadata {
    name = "kube-bench"
  }
}

# Exempts the kube-bench CronJob (Sprint 6) from the restricted Pod Security
# policies it intentionally violates — hostPID and read-only hostPath mounts
# are how it reads node-level CIS config, and its upstream image runs as root
# with default capabilities/seccomp. Scoped to the "kube-bench" namespace only
# (see features.policyExceptions.namespace above), one PolicyException covers
# both the raw CronJob rules and their Kyverno-autogenerated Pod-controller
# equivalents.
resource "kubectl_manifest" "kube_bench_policy_exception" {
  yaml_body = yamlencode({
    apiVersion = "kyverno.io/v2beta1"
    kind       = "PolicyException"
    metadata = {
      name      = "kube-bench-exception"
      namespace = "kube-bench"
    }
    spec = {
      exceptions = [
        { policyName = "disallow-host-namespaces", ruleNames = ["host-namespaces", "autogen-host-namespaces", "autogen-cronjob-host-namespaces"] },
        { policyName = "disallow-host-path", ruleNames = ["host-path", "autogen-host-path", "autogen-cronjob-host-path"] },
        { policyName = "disallow-privilege-escalation", ruleNames = ["privilege-escalation", "autogen-privilege-escalation", "autogen-cronjob-privilege-escalation"] },
        { policyName = "disallow-capabilities-strict", ruleNames = ["require-drop-all", "autogen-require-drop-all", "autogen-cronjob-require-drop-all"] },
        { policyName = "require-run-as-nonroot", ruleNames = ["run-as-non-root", "autogen-run-as-non-root", "autogen-cronjob-run-as-non-root"] },
        { policyName = "restrict-seccomp-strict", ruleNames = ["check-seccomp-strict", "autogen-check-seccomp-strict", "autogen-cronjob-check-seccomp-strict"] },
        { policyName = "restrict-volume-types", ruleNames = ["restricted-volumes", "autogen-restricted-volumes", "autogen-cronjob-restricted-volumes"] },
      ]
      match = {
        any = [
          {
            resources = {
              kinds      = ["Pod", "CronJob", "Job"]
              namespaces = ["kube-bench"]
            }
          }
        ]
      }
    }
  })

  depends_on = [helm_release.kyverno_policies, kubernetes_namespace.kube_bench]
}

# No mutable ":latest" tags — every workload must pin to an immutable reference so
# Trivy/Cosign verdicts (Sprint 3) stay attached to the exact image that runs.
resource "kubectl_manifest" "disallow_latest_tag" {
  yaml_body = yamlencode({
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "disallow-latest-tag"
    }
    spec = {
      validationFailureAction = "Enforce"
      background              = true
      rules = [
        {
          name = "require-image-tag"
          match = {
            any = [{ resources = { kinds = ["Pod"] } }]
          }
          validate = {
            message = "Images must not use the ':latest' tag — pin to an immutable digest or version"
            pattern = {
              spec = {
                containers = [
                  { image = "!*:latest" }
                ]
              }
            }
          }
        }
      ]
    }
  })

  depends_on = [helm_release.kyverno]
}

# Supply-chain gate: only run images that (a) come from our ACR and (b) carry a
# valid Cosign signature from the pipeline's keyless/key-based identity (Sprint 3).
# Left disabled (count = 0) until a public key is provisioned, so an empty value
# here can't accidentally lock the cluster out of starting any pod.
resource "kubectl_manifest" "verify_image_signatures" {
  count = var.cosign_public_key != "" ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "verify-image-signatures"
    }
    spec = {
      validationFailureAction = "Enforce"
      background              = false
      rules = [
        {
          name = "check-cosign-signature"
          match = {
            any = [{ resources = { kinds = ["Pod"] } }]
          }
          verifyImages = [
            {
              imageReferences = ["${var.acr_login_server}/*"]
              attestors = [
                {
                  entries = [
                    { keys = { publicKeys = var.cosign_public_key } }
                  ]
                }
              ]
            }
          ]
        }
      ]
    }
  })

  depends_on = [helm_release.kyverno]
}

# Namespace isolation: every newly created namespace (other than system ones)
# automatically gets a default-deny-ingress NetworkPolicy. Combined with the AKS
# Azure network policy plugin, this is the enforcement layer for Zero Trust east-west
# traffic — workloads must explicitly opt in to receiving traffic (Sprint 4).
resource "kubectl_manifest" "generate_default_deny_networkpolicy" {
  yaml_body = yamlencode({
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "add-default-networkpolicy"
    }
    spec = {
      rules = [
        {
          name = "default-deny-ingress"
          match = {
            any = [{ resources = { kinds = ["Namespace"] } }]
          }
          exclude = {
            any = [
              { resources = { namespaces = ["kube-system", "kyverno", "gatekeeper-system"] } }
            ]
          }
          generate = {
            apiVersion  = "networking.k8s.io/v1"
            kind        = "NetworkPolicy"
            name        = "default-deny-ingress"
            namespace   = "{{request.object.metadata.name}}"
            synchronize = true
            data = {
              spec = {
                podSelector = {}
                policyTypes = ["Ingress"]
              }
            }
          }
        }
      ]
    }
  })

  depends_on = [helm_release.kyverno]
}
