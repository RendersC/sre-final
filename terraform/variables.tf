variable "cluster_name" {
  description = "Name of the local Kind cluster"
  type        = string
  default     = "sre-final"
}

variable "app_namespace" {
  description = "Namespace where the ecom-api workload lives"
  type        = string
  default     = "ecom"
}

variable "monitoring_namespace" {
  description = "Namespace for Prometheus/Grafana/Alertmanager stack"
  type        = string
  default     = "monitoring"
}

variable "kube_prometheus_stack_version" {
  description = "Helm chart version for prometheus-community/kube-prometheus-stack"
  type        = string
  default     = "61.3.2"
}

variable "metrics_server_version" {
  description = "Helm chart version for metrics-server (needed for HPA)"
  type        = string
  default     = "3.12.1"
}

variable "grafana_admin_password" {
  description = "Initial admin password for Grafana (change before any real use)"
  type        = string
  default     = "sre-final-admin"
  sensitive   = true
}
