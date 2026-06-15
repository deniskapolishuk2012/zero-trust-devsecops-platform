variable "schedule" {
  description = "Cron schedule for the recurring CIS benchmark scan"
  type        = string
  default     = "0 3 * * *"
}

variable "kube_bench_version" {
  type    = string
  default = "v0.7.2"
}

variable "namespace" {
  description = "Namespace the CronJob runs in — created by module.kyverno alongside its PolicyException"
  type        = string
}
