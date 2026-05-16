# Service Level Objectives (SLOs)

## Service: `ecom-api`

User-facing REST API. Two user journeys matter the most:
- browsing the catalog (`GET /api/products`, `GET /api/products/{id}`)
- placing an order (`POST /api/orders`)

## SLIs

| # | SLI | PromQL |
|---|-----|--------|
| 1 | **Availability** — fraction of HTTP requests that did not return 5xx | `1 - (sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])))` |
| 2 | **Latency** — p95 request duration | `histogram_quantile(0.95, sum by (le, route) (rate(http_request_duration_seconds_bucket[5m])))` |
| 3 | **Order success rate** — orders accepted (201) divided by orders attempted | `sum(rate(orders_created_total[5m])) / (sum(rate(orders_created_total[5m])) + sum(rate(orders_failed_total[5m])))` |

## SLOs (28-day rolling window)

| SLI | Target | Error budget (28 d) |
|---|---|---|
| Availability | **99.5%** of requests succeed (non-5xx) | 0.5% × 28 d ≈ **3h 21m** of downtime allowed |
| Latency p95 | **< 300 ms** for `/api/products*` and **< 500 ms** for `/api/orders` | up to 5% of 5-minute windows may exceed |
| Order success rate | **≥ 99%** of attempted orders accepted (excluding `insufficient stock` 422s) | up to 1% of orders may fail with 5xx |

## Error-budget policy

| Budget remaining | Action |
|---|---|
| > 50% | Ship features freely. |
| 10 – 50% | New work requires a risk review; prioritize reliability fixes alongside features. |
| < 10% | Code freeze on the `ecom-api` repository. All eng effort goes to reliability work until budget recovers above 25%. |
| Exhausted | Page the SRE on-call, declare incident, and freeze production deploys until root cause is mitigated. |

## How SLOs map to alerts

| Alert | Threshold | For | Severity | Rationale |
|---|---|---|---|---|
| `EcomApiHighErrorRate` | error ratio > 5% | 2m | critical | Burning budget 10× faster than the SLO permits. |
| `EcomApiHighLatencyP95` | p95 > 500ms | 5m | warning | Approaching the order-flow latency SLO ceiling. |
| `EcomApiPodNotReady` | 0 ready pods in `ecom` | 2m | critical | Service is fully down — SLO breach in progress. |
| `EcomApiHighCpu` | per-pod CPU > 200m | 5m | warning | Validates the HPA is keeping up; if it fires while max replicas is reached we need to raise `maxReplicas`. |

Alert rules live in [`k8s/06-prometheusrule.yaml`](../k8s/06-prometheusrule.yaml).
The matching Grafana panels live in
[`monitoring/grafana/dashboards/ecom-api-sre-dashboard.json`](../monitoring/grafana/dashboards/ecom-api-sre-dashboard.json).
