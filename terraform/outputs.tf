output "cluster_name" {
  description = "Name of the provisioned Kind cluster"
  value       = kind_cluster.this.name
}

output "kubeconfig_path" {
  description = "Path to the kubeconfig file written by Terraform"
  value       = local_file.kubeconfig.filename
}

output "app_namespace" {
  description = "Namespace for the application workload"
  value       = kubernetes_namespace.app.metadata[0].name
}

output "monitoring_namespace" {
  description = "Namespace for the monitoring stack"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "grafana_url" {
  description = "Grafana NodePort URL (admin / see variables.grafana_admin_password)"
  value       = "http://localhost:30030"
}

output "prometheus_url" {
  description = "Prometheus NodePort URL"
  value       = "http://localhost:30090"
}

output "alertmanager_url" {
  description = "Alertmanager NodePort URL"
  value       = "http://localhost:30080"
}
