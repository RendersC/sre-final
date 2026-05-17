# SRE Capstone вЂ” Production Readiness Review

End-to-end, reproducible SRE stack for a Go e-commerce microservice
(`ecom-api`), deployable from a single laptop in ~5 minutes.

| Block | Tooling |
|---|---|
| Application | Go 1.22 REST API with native Prometheus metrics |
| IaC | Terraform вЂ” Kind cluster + Helm releases |
| CI/CD | GitHub Actions в†’ `ghcr.io` |
| Observability | kube-prometheus-stack (Prometheus + Grafana + Alertmanager) |
| Reliability | HPA v2 (CPU + memory), Locust load-test |

> **Team:** Adildabek Nurassyl, Artem Safaryan вЂ” group SE2408.

## Repository layout

```
.
в”њв”Ђв”Ђ app/                   # Go microservice (Dockerfile, main.go, go.mod)
в”њв”Ђв”Ђ terraform/             # IaC вЂ” kind cluster + helm releases (kps, metrics-server)
в”њв”Ђв”Ђ k8s/                   # Deployment, Service, HPA, ServiceMonitor, PrometheusRule
в”њв”Ђв”Ђ monitoring/
в”‚   в”њв”Ђв”Ђ alertmanager/      # AlertmanagerConfig (routes & receivers)
в”‚   в””в”Ђв”Ђ grafana/           # SRE Golden Signals dashboard
в”њв”Ђв”Ђ loadtest/              # Locust load test (staged spike profile)
в”њв”Ђв”Ђ scripts/               # bootstrap, teardown, smoke-test
в”њв”Ђв”Ђ .github/workflows/     # CI/CD pipeline (test в†’ build в†’ push в†’ patch)
в”њв”Ђв”Ђ docs/                  # architecture.md, slo.md, runbook.md
в””в”Ђв”Ђ REPORT.md              # Written report (render to PDF for submission)
```

## Quick start

### Prerequisites
- Docker Desktop
- `terraform >= 1.5`, `kubectl`, `kind`
- Optional: Python 3.11+ for Locust

### Bring everything up

```bash
# Linux / macOS / WSL
./scripts/bootstrap.sh

# Windows PowerShell
./scripts/bootstrap.ps1
```

Expected output ends with:
```
Grafana       : http://localhost:30030  (admin / sre-final-admin)
Prometheus    : http://localhost:30090
Alertmanager  : http://localhost:30080
ecom-api      : http://localhost:30081/api/products
```

### Smoke test

```bash
./scripts/smoke-test.sh
```

### Generate load

```bash
cd loadtest
pip install -r requirements.txt
locust -f locustfile.py --host http://localhost:30081
# open http://localhost:8089 and click "Start swarming"
```

While the load runs, watch the system react:

```bash
watch -n 2 'kubectl -n ecom get hpa,pods'
```

### Tear it down

```bash
./scripts/teardown.sh
```

## Mapping deliverables to the rubric

| Rubric item | Where to look |
|---|---|
| **IaC вЂ” providers, reproducibility, state** (15 pt) | `terraform/` + `terraform/README.md` |
| **CI/CD вЂ” build, registry, deploy** (15 pt) | `.github/workflows/ci-cd.yaml`, screenshot in `REPORT.md` |
| **Observability вЂ” metrics, dashboards, alerts** (15 pt) | `k8s/05-servicemonitor.yaml`, `k8s/06-prometheusrule.yaml`, `monitoring/grafana/`, `monitoring/alertmanager/` |
| **SRE Operations вЂ” SLOs, scaling, load tests** (15 pt) | `docs/slo.md`, `k8s/04-hpa.yaml`, `loadtest/` |
| **Documentation** (10 pt) | This README, `docs/`, `REPORT.md` |
| **Defense & Demo** (30 pt) | Live demo using the URLs above + `REPORT.md` walkthrough |

See [`REPORT.md`](REPORT.md) for the full written report (export to PDF for submission).
