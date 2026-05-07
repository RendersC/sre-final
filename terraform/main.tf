################################################################################
# Local Kubernetes cluster (Kind) — gives us a reproducible-from-scratch target.
################################################################################
resource "kind_cluster" "this" {
  name           = var.cluster_name
  node_image     = "kindest/node:v1.30.0"
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    # 1 control-plane + 2 workers — enough to demonstrate scheduling & HPA.
    node {
      role = "control-plane"

      # Expose ingress ports for port-forwarded demos.
      extra_port_mappings {
        container_port = 30080
        host_port      = 30080
        protocol       = "TCP"
      }
      extra_port_mappings {
        container_port = 30090
        host_port      = 30090
        protocol       = "TCP"
      }
      extra_port_mappings {
        container_port = 30030
        host_port      = 30030
        protocol       = "TCP"
      }
    }

    node {
      role = "worker"
    }

    node {
      role = "worker"
    }
  }
}

# Write kubeconfig to disk so kubectl/helm/external tools can use it.
resource "local_file" "kubeconfig" {
  content         = kind_cluster.this.kubeconfig
  filename        = "${path.module}/kubeconfig"
  file_permission = "0600"
}

################################################################################
# Namespaces
################################################################################
resource "kubernetes_namespace" "app" {
  metadata {
    name = var.app_namespace
    labels = {
      "app.kubernetes.io/part-of" = "sre-final"
    }
  }
  depends_on = [kind_cluster.this]
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.monitoring_namespace
    labels = {
      "app.kubernetes.io/part-of" = "sre-final"
    }
  }
  depends_on = [kind_cluster.this]
}

################################################################################
# metrics-server — required for HPA to read CPU/Memory metrics on Kind.
################################################################################
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.metrics_server_version

  # Kind serves kubelet certs from a self-signed CA — relax verification.
  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }

  depends_on = [kind_cluster.this]
}

################################################################################
# kube-prometheus-stack — Prometheus + Grafana + Alertmanager + Operator.
################################################################################
resource "helm_release" "kube_prometheus_stack" {
  name       = "kps"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.kube_prometheus_stack_version

  timeout = 600

  values = [
    yamlencode({
      grafana = {
        adminPassword = var.grafana_admin_password
        service = {
          type     = "NodePort"
          nodePort = 30030
        }
        defaultDashboardsEnabled = true
        sidecar = {
          dashboards = {
            enabled         = true
            searchNamespace = "ALL"
            label           = "grafana_dashboard"
          }
        }
      }

      prometheus = {
        service = {
          type     = "NodePort"
          nodePort = 30090
        }
        prometheusSpec = {
          # Pick up ServiceMonitors from any namespace, not only those labelled by the chart.
          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues     = false
          ruleSelectorNilUsesHelmValues           = false

          retention = "7d"

          resources = {
            requests = { cpu = "100m", memory = "400Mi" }
            limits   = { cpu = "1",    memory = "1Gi"   }
          }
        }
      }

      alertmanager = {
        service = {
          type     = "NodePort"
          nodePort = 30080
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}
