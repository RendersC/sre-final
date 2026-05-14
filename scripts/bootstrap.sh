#!/usr/bin/env bash
# Brings up the whole stack from scratch on a developer laptop.
#   1. terraform apply  -> Kind + metrics-server + kube-prometheus-stack
#   2. build app image  -> docker build
#   3. load image into Kind (no registry needed for local demo)
#   4. apply k8s/ manifests with the local image tag
#   5. install Grafana dashboard ConfigMap
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-sre-final}"
IMAGE_LOCAL="ecom-api:dev"

echo "==> [1/5] terraform apply"
pushd "$ROOT/terraform" >/dev/null
terraform init -upgrade
terraform apply -auto-approve
export KUBECONFIG="$(terraform output -raw kubeconfig_path)"
popd >/dev/null

echo "==> [2/5] docker build"
docker build -t "$IMAGE_LOCAL" "$ROOT/app"

echo "==> [3/5] kind load docker-image"
kind load docker-image "$IMAGE_LOCAL" --name "$CLUSTER_NAME"

echo "==> [4/5] kubectl apply manifests (patched to local image)"
TMP=$(mktemp -d)
cp -r "$ROOT/k8s/." "$TMP/"
sed -i.bak "s|ghcr.io/OWNER/ecom-api:.*|$IMAGE_LOCAL|" "$TMP/02-deployment.yaml"
# imagePullPolicy must be Never/IfNotPresent for a kind-loaded image:
sed -i.bak "s|imagePullPolicy: IfNotPresent|imagePullPolicy: Never|" "$TMP/02-deployment.yaml"
kubectl apply -f "$TMP/"
kubectl -n ecom rollout status deployment/ecom-api --timeout=180s

echo "==> [5/5] installing Grafana dashboard"
kubectl -n monitoring create configmap ecom-api-sre-dashboard \
  --from-file="$ROOT/monitoring/grafana/dashboards/ecom-api-sre-dashboard.json" \
  --dry-run=client -o yaml | \
  kubectl label --local --dry-run=client -o yaml -f - grafana_dashboard=1 | \
  kubectl apply -f -

cat <<EOF

================================================================================
  ✓ Bootstrap complete.

  Grafana       : http://localhost:30030  (admin / sre-final-admin)
  Prometheus    : http://localhost:30090
  Alertmanager  : http://localhost:30080
  ecom-api      : http://localhost:30081/api/products

  Useful follow-ups:
    kubectl -n ecom get pods,hpa
    kubectl -n monitoring get pods
    cd loadtest && locust -f locustfile.py --host http://localhost:30081
================================================================================
EOF
