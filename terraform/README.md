# Terraform — Infrastructure as Code

Provisions a local production-like Kubernetes environment **from scratch**:

| Resource | Purpose |
|---|---|
| `kind_cluster.this` | 1 control-plane + 2 worker Kubernetes cluster on Docker |
| `kubernetes_namespace.app` | Namespace `ecom` for the application |
| `kubernetes_namespace.monitoring` | Namespace `monitoring` for observability stack |
| `helm_release.metrics_server` | Enables HPA (CPU/memory metrics) |
| `helm_release.kube_prometheus_stack` | Prometheus + Grafana + Alertmanager + Operator |

## Prerequisites

- Docker Desktop running
- `terraform >= 1.5`
- `kubectl`
- (Already bundled in chart, no extra install needed)

## Usage

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

After apply finishes:

```bash
export KUBECONFIG=$(terraform output -raw kubeconfig_path)
kubectl get nodes
kubectl get pods -A
```

UI access (NodePort, all bound to the Kind control-plane container):

| Service      | URL                       | Credentials |
|--------------|---------------------------|---|
| Grafana      | http://localhost:30030    | `admin` / value of `var.grafana_admin_password` |
| Prometheus   | http://localhost:30090    | — |
| Alertmanager | http://localhost:30080    | — |

## State management

Default state is **local** (`terraform.tfstate`) for grading reproducibility.
For team use switch the backend to one of:

```hcl
# Option A — S3 + DynamoDB locking
terraform {
  backend "s3" {
    bucket         = "sre-final-tfstate"
    key            = "sre-final/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "sre-final-tflock"
    encrypt        = true
  }
}

# Option B — GCS
terraform {
  backend "gcs" {
    bucket = "sre-final-tfstate"
    prefix = "sre-final"
  }
}
```

State is sensitive — do not commit `terraform.tfstate` (already in `.gitignore`).

## Reproducibility

A fresh `terraform destroy && terraform apply` rebuilds the entire stack in ~3–5
minutes. Cluster image, chart versions, and namespace names are all variables
(see `variables.tf`) so the deployment is fully pinned.
