# Screenshots

Drop the screenshots used in `REPORT.md` here. Suggested filenames (referenced
from the report):

| File | What to capture |
|---|---|
| `01-terraform-apply.png`     | Successful `terraform apply` output |
| `02-kubectl-get-pods.png`    | `kubectl get pods -A` showing app + monitoring pods Ready |
| `03-github-actions-green.png`| Green CI/CD run on GitHub Actions |
| `04-ghcr-image.png`          | The pushed image in `ghcr.io` packages tab |
| `05-grafana-dashboard.png`   | SRE Golden Signals dashboard with traffic |
| `06-prometheus-targets.png`  | Prometheus Targets page showing `ecom-api` UP |
| `07-alertmanager-firing.png` | Alertmanager UI with an alert firing |
| `08-hpa-scaling.png`         | `kubectl get hpa,pods` during a load spike |
| `09-locust-results.png`      | Locust UI / stats at end of run |
