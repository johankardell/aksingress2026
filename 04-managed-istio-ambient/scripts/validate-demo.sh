#!/bin/bash
set -e
set -o pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

RESOURCE_GROUP="rg-04-istio-ambient-demo"
DEPLOYMENT_NAME="istio-ambient-demo-deployment"
APP_NAMESPACE="mesh-demo"
FAILURES=0

check() {
  local description="$1"
  shift

  echo -n "${description}... "
  if "$@" >/tmp/validate-demo-check.log 2>&1; then
    echo -e "${GREEN}ok${NC}"
  else
    echo -e "${RED}failed${NC}"
    cat /tmp/validate-demo-check.log
    FAILURES=$((FAILURES + 1))
  fi
}

check_optional() {
  local description="$1"
  shift

  echo -n "${description}... "
  if "$@" >/tmp/validate-demo-check.log 2>&1; then
    echo -e "${GREEN}ok${NC}"
  else
    echo -e "${YELLOW}warning${NC}"
    cat /tmp/validate-demo-check.log
  fi
}

command -v az >/dev/null 2>&1 || { echo -e "${RED}Azure CLI is required but not installed.${NC}" >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}kubectl is required but not installed.${NC}" >&2; exit 1; }

AKS_NAME=$(az deployment group show --resource-group "$RESOURCE_GROUP" --name "$DEPLOYMENT_NAME" --query properties.outputs.aksClusterName.value --output tsv)
APPNET_NAME=$(az deployment group show --resource-group "$RESOURCE_GROUP" --name "$DEPLOYMENT_NAME" --query properties.outputs.appNetName.value --output tsv)
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_NAME" --overwrite-existing --output none

check "AKS cluster exists" az aks show --resource-group "$RESOURCE_GROUP" --name "$AKS_NAME"
check_optional "Application Network member exists" az appnet member show --resource-group "$RESOURCE_GROUP" --appnet-name "$APPNET_NAME" --member-name "$AKS_NAME"
check "Gateway API CRDs exist" kubectl get crd gateways.gateway.networking.k8s.io httproutes.gateway.networking.k8s.io
check_optional "Istio ambient CRDs exist" kubectl get crd telemetries.telemetry.istio.io
check_optional "ztunnel daemonset is present" kubectl get daemonset -A -l app=ztunnel
check_optional "Istio CNI or Application Network system pods are present" kubectl get pods -A -l k8s-app=istio-cni-node
check "mesh-demo namespace is ambient-labeled" kubectl get namespace "$APP_NAMESPACE" -o jsonpath='{.metadata.labels.istio\.io/dataplane-mode}'
check "mesh workloads are ready" kubectl wait --for=condition=available --timeout=60s deployment/frontend deployment/orders deployment/inventory -n "$APP_NAMESPACE"
check "Gateway and HTTPRoute exist" bash -c "kubectl get gateway mesh-demo-gateway -n '$APP_NAMESPACE' && kubectl get httproute frontend-route -n '$APP_NAMESPACE'"
check_optional "Waypoint Gateway exists" kubectl get gateway mesh-demo-waypoint -n "$APP_NAMESPACE"
check_optional "Prometheus is reachable in-cluster" kubectl get svc prometheus-server -n monitoring
check_optional "Kiali is reachable in-cluster" kubectl get svc kiali -n kiali-system

EXTERNAL_IP=$(kubectl get gateway mesh-demo-gateway -n "$APP_NAMESPACE" -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || echo "")
if [ -n "$EXTERNAL_IP" ]; then
  check_optional "frontend /api/call responds" curl -fsS "http://${EXTERNAL_IP}/api/call"
else
  echo -e "${YELLOW}Gateway external address is not assigned yet; skipping external traffic check.${NC}"
fi

rm -f /tmp/validate-demo-check.log

if [ "$FAILURES" -gt 0 ]; then
  echo -e "${RED}${FAILURES} required validation checks failed.${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Required validation checks passed${NC}"
