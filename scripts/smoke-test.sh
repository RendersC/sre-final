#!/usr/bin/env bash
# Hits the API a few times and prints the responses.
set -euo pipefail
BASE="${BASE:-http://localhost:30081}"

echo "--- GET /healthz ---"
curl -fsS "$BASE/healthz" && echo

echo "--- GET /api/products ---"
curl -fsS "$BASE/api/products" | head -c 500 && echo

echo "--- GET /api/products/1 ---"
curl -fsS "$BASE/api/products/1" && echo

echo "--- POST /api/orders ---"
curl -fsS -X POST "$BASE/api/orders" \
  -H 'content-type: application/json' \
  -d '{"product_id":1,"quantity":2}' && echo

echo "--- /metrics (head) ---"
curl -fsS "$BASE/metrics" | head -n 20
