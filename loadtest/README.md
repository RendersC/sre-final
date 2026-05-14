# Load Testing

## Install

```bash
python -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

## Run

Point Locust at the NodePort the application is exposed on (we use 30081 by
default — see `k8s/07-service-nodeport.yaml`).

```bash
# Quick smoke
locust -f locustfile.py --headless \
       --host http://localhost:30081 \
       --users 100 --spawn-rate 20 --run-time 3m

# Full staged spike (uses StagedSpike load shape) — best for demo screenshots
locust -f locustfile.py --host http://localhost:30081
# open http://localhost:8089 and click "Start swarming"
```

While Locust runs, watch HPA scale:

```bash
watch -n 2 'kubectl -n ecom get hpa,pods'
```

And open the Grafana dashboard at http://localhost:30030 to capture:

1. Request rate climbing
2. p95 latency staying under SLO (or crossing it during the spike)
3. Pod count vs HPA desired replicas
4. Alerts firing in Alertmanager during sustained pressure
