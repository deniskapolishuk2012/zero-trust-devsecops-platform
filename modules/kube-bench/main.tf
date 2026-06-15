# Compliance as Code (Sprint 6): runs the CIS Kubernetes Benchmark — using AKS's own
# profile (aks-1.0) rather than generic CIS, since AKS manages the control plane and
# many upstream checks don't apply — against every node on a recurring schedule.
# hostPID + read-only hostPath mounts give it the same view kube-bench needs without
# granting write access to node config.
#
# kubectl_manifest (gavinbunney/kubectl), not kubernetes_manifest: the latter needs
# the live cluster's OpenAPI schema at plan time, which doesn't exist on a first
# apply before module.aks has run.
resource "kubectl_manifest" "kube_bench_cronjob" {
  yaml_body = yamlencode({
    apiVersion = "batch/v1"
    kind       = "CronJob"
    metadata = {
      name      = "kube-bench"
      namespace = var.namespace
    }
    spec = {
      schedule = var.schedule
      jobTemplate = {
        spec = {
          template = {
            spec = {
              hostPID = true
              containers = [
                {
                  name    = "kube-bench"
                  image   = "docker.io/aquasec/kube-bench:${var.kube_bench_version}"
                  command = ["kube-bench", "run", "--benchmark", "aks-1.0", "--json"]
                  volumeMounts = [
                    { name = "var-lib-kubelet", mountPath = "/var/lib/kubelet", readOnly = true },
                    { name = "etc-systemd", mountPath = "/etc/systemd", readOnly = true },
                    { name = "etc-kubernetes", mountPath = "/etc/kubernetes", readOnly = true },
                  ]
                }
              ]
              restartPolicy = "Never"
              volumes = [
                { name = "var-lib-kubelet", hostPath = { path = "/var/lib/kubelet" } },
                { name = "etc-systemd", hostPath = { path = "/etc/systemd" } },
                { name = "etc-kubernetes", hostPath = { path = "/etc/kubernetes" } },
              ]
            }
          }
        }
      }
    }
  })

}
