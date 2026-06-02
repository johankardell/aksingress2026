#!/bin/bash
set -e
set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

RESOURCE_GROUP="rg-04-istio-ambient-demo"
DEPLOYMENT_NAME="istio-ambient-demo-deployment"
APP_NAMESPACE="mesh-demo"
REQUESTS="${REQUESTS:-60}"
SLEEP_SECONDS="${SLEEP_SECONDS:-2}"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
source "$REPO_ROOT/shared/scripts/acr-image.sh"

command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}kubectl is required but not installed.${NC}" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo -e "${RED}curl is required but not installed.${NC}" >&2; exit 1; }

EXTERNAL_IP="${FRONTEND_HOST:-}"
if [ -z "$EXTERNAL_IP" ]; then
  EXTERNAL_IP=$(kubectl get gateway mesh-demo-gateway -n "$APP_NAMESPACE" -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || echo "")
fi

if [ -z "$EXTERNAL_IP" ] && command -v az >/dev/null 2>&1; then
  AKS_NAME=$(az deployment group show --resource-group "$RESOURCE_GROUP" --name "$DEPLOYMENT_NAME" --query properties.outputs.aksClusterName.value --output tsv 2>/dev/null || true)
  if [ -n "$AKS_NAME" ]; then
    az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_NAME" --overwrite-existing --output none 2>/dev/null || true
    EXTERNAL_IP=$(kubectl get gateway mesh-demo-gateway -n "$APP_NAMESPACE" -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || echo "")
  fi
fi

if [ -z "$EXTERNAL_IP" ]; then
  echo -e "${RED}Could not determine frontend Gateway address. Set FRONTEND_HOST=<ip-or-host> and retry.${NC}" >&2
  exit 1
fi

BASE_URL="http://${EXTERNAL_IP}"
echo -e "${GREEN}Generating ${REQUESTS} requests against ${BASE_URL}${NC}"
echo -e "${YELLOW}Open Kiali after this with: kubectl port-forward -n kiali-system svc/kiali 20001:20001${NC}"

for i in $(seq 1 "$REQUESTS"); do
  request_id="mesh-demo-${i}-$(date +%s)"
  curl -fsS -H "X-Request-Id: ${request_id}" "${BASE_URL}/api/call" >/dev/null
  if [ $((i % 10)) -eq 0 ]; then
    echo "Sent ${i}/${REQUESTS} requests"
  fi
  sleep "$SLEEP_SECONDS"
done

echo -e "${GREEN}✓ Traffic generation completed${NC}"
