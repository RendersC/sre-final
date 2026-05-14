# PowerShell version of bootstrap.sh — same five steps for Windows users.
$ErrorActionPreference = "Stop"

$Root        = Split-Path -Parent $PSScriptRoot
$ClusterName = if ($env:CLUSTER_NAME) { $env:CLUSTER_NAME } else { "sre-final" }
$ImageLocal  = "ecom-api:dev"

Write-Host "==> [1/5] terraform apply" -ForegroundColor Cyan
Push-Location "$Root\terraform"
terraform init -upgrade
terraform apply -auto-approve
$env:KUBECONFIG = (terraform output -raw kubeconfig_path)
Pop-Location

Write-Host "==> [2/5] docker build" -ForegroundColor Cyan
docker build -t $ImageLocal "$Root\app"

Write-Host "==> [3/5] kind load docker-image" -ForegroundColor Cyan
kind load docker-image $ImageLocal --name $ClusterName

Write-Host "==> [4/5] kubectl apply manifests (patched to local image)" -ForegroundColor Cyan
$Tmp = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "sre-final-$([guid]::NewGuid())")
Copy-Item "$Root\k8s\*" $Tmp.FullName -Recurse
$Dep = Join-Path $Tmp.FullName "02-deployment.yaml"
(Get-Content $Dep) `
    -replace 'ghcr\.io/OWNER/ecom-api:.*', $ImageLocal `
    -replace 'imagePullPolicy: IfNotPresent', 'imagePullPolicy: Never' |
    Set-Content $Dep -Encoding utf8
kubectl apply -f $Tmp.FullName
kubectl -n ecom rollout status deployment/ecom-api --timeout=180s

Write-Host "==> [5/5] installing Grafana dashboard" -ForegroundColor Cyan
$DashJson = Join-Path $Root "monitoring\grafana\dashboards\ecom-api-sre-dashboard.json"
kubectl -n monitoring create configmap ecom-api-sre-dashboard `
    --from-file=$DashJson `
    --dry-run=client -o yaml |
    kubectl label --local --dry-run=client -o yaml -f - grafana_dashboard=1 |
    kubectl apply -f -

Write-Host @"

================================================================================
  Bootstrap complete.

  Grafana       : http://localhost:30030  (admin / sre-final-admin)
  Prometheus    : http://localhost:30090
  Alertmanager  : http://localhost:30080
  ecom-api      : http://localhost:30081/api/products

  Useful follow-ups:
    kubectl -n ecom get pods,hpa
    kubectl -n monitoring get pods
    cd loadtest; locust -f locustfile.py --host http://localhost:30081
================================================================================
"@ -ForegroundColor Green
