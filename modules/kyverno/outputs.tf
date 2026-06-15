output "kyverno_namespace" {
  value = helm_release.kyverno.namespace
}

output "kyverno_release_status" {
  value = helm_release.kyverno.status
}

output "kube_bench_namespace" {
  value = kubernetes_namespace.kube_bench.metadata[0].name
}
