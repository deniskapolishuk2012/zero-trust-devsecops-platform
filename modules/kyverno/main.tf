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
  create_namespace = true

  set {
    name  = "replicaCount"
    value = "1"
  }
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
