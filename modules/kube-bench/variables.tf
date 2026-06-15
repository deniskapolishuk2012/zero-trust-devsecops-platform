variable "schedule" {
  description = "Cron schedule for the recurring CIS benchmark scan"
  type        = string
  default     = "0 3 * * *"
}

variable "kube_bench_version" {
  type    = string
  default = "v0.7.2"
}
