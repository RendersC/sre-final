# Runbook — `ecom-api`

Use this when an alert fires. Each section is keyed to an alert in
`k8s/06-prometheusrule.yaml`.

## High Error Rate (`EcomApiHighErrorRate`)

**Symptom:** `5xx / total > 5%` for 2 minutes.

1. Confirm the spike on the Grafana SRE dashboard → "Error ratio" panel.
2. Identify which route is failing:
   ```promql
   topk(5, sum by (route, status) (rate(http_requests_total{status=~"5.."}[5m])))
   ```
3. Check pod state:
   ```bash
   kubectl -n ecom get pods
   kubectl -n ecom logs -l app.kubernetes.io/name=ecom-api --tail=200
   ```
4. Recent rollout? `kubectl -n ecom rollout history deployment/ecom-api` →
   `kubectl -n ecom rollout undo deployment/ecom-api` if the bad version
   correlates with the start of the spike.
5. If the cause is a downstream dependency, set the failing route to return
   503 fast (circuit-break) and post in `#sre-oncall`.

## High Latency p95 (`EcomApiHighLatencyP95`)

**Symptom:** `p95 latency > 500ms` for 5 minutes.

1. Open the dashboard → "Latency p50/p95/p99 by route".
2. Is the increase uniform (infra) or localized to one route (code path)?
3. Check pod count vs HPA desired:
   ```bash
   kubectl -n ecom get hpa
   ```
   - If `desired == max`, raise `maxReplicas` in `k8s/04-hpa.yaml`.
   - If desired hasn't grown, check `metrics-server` is healthy:
     ```bash
     kubectl top pods -n ecom
     ```
4. Check node pressure: `kubectl describe nodes | grep -E '(Allocated|Pressure)'`.

## Service Down (`EcomApiPodNotReady`)

**Symptom:** Zero Ready pods in `ecom` for 2 minutes.

1. `kubectl -n ecom describe pods` → look at `Events`.
2. Common causes:
   - ImagePullBackOff → confirm `ghcr.io/<org>/ecom-api:<sha>` exists and the
     pull secret is current.
   - CrashLoopBackOff → `kubectl -n ecom logs --previous` for the panic.
   - OOMKilled → bump `resources.limits.memory` in `k8s/02-deployment.yaml`.
3. If the cluster itself is down, escalate to platform on-call.

## Sustained High CPU (`EcomApiHighCpu`)

**Symptom:** Avg per-pod CPU > 200m for 5m (matches HPA target × limit).

1. Confirm HPA is scaling: `kubectl -n ecom get hpa ecom-api -w`.
2. If `currentReplicas == maxReplicas`, scale the ceiling:
   ```bash
   kubectl -n ecom patch hpa ecom-api --type=merge -p '{"spec":{"maxReplicas":12}}'
   ```
3. Profile the hot route — `/api/work` is a synthetic CPU burner; remove it
   from production traffic if it leaks in.

## General triage commands

```bash
kubectl -n ecom get pods,hpa,svc
kubectl -n ecom describe deployment ecom-api
kubectl -n ecom top pods
kubectl -n monitoring get pods
# Open the dashboards
xdg-open http://localhost:30030      # Grafana
xdg-open http://localhost:30090      # Prometheus
xdg-open http://localhost:30080      # Alertmanager
```
