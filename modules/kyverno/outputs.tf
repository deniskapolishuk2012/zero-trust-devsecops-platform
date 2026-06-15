output "kyverno_namespace" {
  value = helm_release.kyverno.namespace
}

output "kyverno_release_status" {
  value = helm_release.kyverno.status
}
