# Architecture

## High-level diagram

```
                ┌────────────────────────────────────────────────────────────┐
                │                       Developer laptop                     │
                │                                                            │
                │   ┌─────────────┐    terraform apply                       │
                │   │  Terraform  │───────────────────────────────┐          │
                │   └─────────────┘                               ▼          │
                │                                       ┌──────────────────┐ │
                │   ┌──────────────┐  docker build      │   Kind cluster   │ │
                │   │   GitHub     │  push :sha         │  (3 nodes)       │ │
                │   │   Actions    │───────────────►    │                  │ │
                │   └──────┬───────┘  ghcr.io           │  ┌─────────────┐ │ │
                │          │                            │  │ ecom (ns)   │ │ │
                │          ▼                            │  │  Deployment │ │ │
                │   ┌──────────────┐                    │  │   2..8 pods │ │ │
                │   │  ghcr.io     │  pull              │  │   HPA       │ │ │
                │   │ ecom-api:sha │──────────────────► │  │   Service   │ │ │
                │   └──────────────┘                    │  └─────┬───────┘ │ │
                │                                       │        │ scrape  │ │
                │                                       │        ▼         │ │
                │   ┌──────────────┐                    │ ┌──────────────┐ │ │
                │   │   Locust     │  load              │ │ monitoring   │ │ │
                │   │ load tester  │───────────────────►│ │  ns          │ │ │
                │   └──────────────┘  http://NodePort   │ │ Prometheus   │ │ │
                │                                       │ │ Grafana      │ │ │
                │   ┌──────────────┐  port-forward      │ │ Alertmanager │ │ │
                │   │  Browser     │◄──────────────────►│ │   (kps)      │ │ │
                │   └──────────────┘                    │ └──────────────┘ │ │
                │                                       └──────────────────┘ │
                └────────────────────────────────────────────────────────────┘
```

## Components

| Layer | Tool | What it does |
|---|---|---|
| IaC | Terraform 1.5+ (`tehcyx/kind`, `hashicorp/kubernetes`, `hashicorp/helm`) | Reproducible cluster + Helm releases |
| Cluster | Kind v1.30 | Local 3-node Kubernetes |
| Workload | Go 1.22 microservice (`ecom-api`) | E-commerce REST API w/ Prometheus metrics |
| Image registry | GitHub Container Registry (`ghcr.io`) | Versioned images, tagged by commit SHA |
| CI/CD | GitHub Actions | lint → test → build → push → patch manifests |
| Metrics | kube-prometheus-stack (Prometheus Operator) | Scrapes via `ServiceMonitor`, alerts via `PrometheusRule` |
| Dashboards | Grafana 10 | SRE golden-signals dashboard provisioned via sidecar |
| Alerting | Alertmanager | Routing via `AlertmanagerConfig` |
| Scaling | HPA v2 (CPU + memory) + `metrics-server` | 2 → 8 replicas based on load |
| Load testing | Locust 2.31 | Staged spike profile to validate SLOs and HPA |

## Why these choices

- **Kind** instead of EKS/GKE — full reproducibility on a laptop, no cloud bill,
  identical Kubernetes API surface for the grader to verify.
- **kube-prometheus-stack** instead of standalone deployments — gives us
  Operator, CRDs (`ServiceMonitor`, `PrometheusRule`, `AlertmanagerConfig`),
  curated Grafana dashboards, and one upgrade path.
- **Distroless image + non-root + read-only root FS** — production hygiene we
  picked up in the security module.
- **ServiceMonitor** instead of Prometheus annotations — the Operator pattern
  is what real production clusters use.
- **Recording rules** for SLIs — keeps Grafana panels fast and alert
  expressions readable.
