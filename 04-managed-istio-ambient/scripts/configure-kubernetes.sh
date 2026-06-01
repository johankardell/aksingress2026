#!/bin/bash
set -e
set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  Managed Istio Ambient - Kubernetes Configuration${NC}"
echo -e "${GREEN}================================================${NC}"
echo

RESOURCE_GROUP="rg-04-istio-ambient-demo"
DEPLOYMENT_NAME="istio-ambient-demo-deployment"
APP_NAMESPACE="mesh-demo"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
IMAGE_REPOSITORY="aks-ingress-demo"
source "$REPO_ROOT/shared/scripts/acr-image.sh"

command -v az >/dev/null 2>&1 || { echo -e "${RED}Azure CLI is required but not installed.${NC}" >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}kubectl is required but not installed.${NC}" >&2; exit 1; }

select_gateway_class() {
  if [ -n "${GATEWAY_CLASS_NAME:-}" ]; then
    echo "$GATEWAY_CLASS_NAME"
    return
  fi

  local class_name
  class_name=$(kubectl get gatewayclass -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null | grep -Ei 'appnet|application-network|azure|istio' | head -1 || true)
  if [ -z "$class_name" ]; then
    class_name="istio"
  fi

  echo "$class_name"
}

apply_with_image() {
  local file="$1"
  sed \
    -e "s|\${ACR_LOGIN_SERVER}|${ACR_LOGIN_SERVER}|g" \
    -e "s|\${IMAGE_TAG}|${SAMPLE_APP_IMAGE_TAG}|g" \
    "$file" | kubectl apply -f -
}

apply_gateway() {
  local file="$1"
  sed -e "s|\${GATEWAY_CLASS_NAME}|${GATEWAY_CLASS_NAME}|g" "$file" | kubectl apply -f -
}

echo -e "${YELLOW}[1/7] Reading infrastructure outputs...${NC}"
AKS_NAME=$(az deployment group show --resource-group "$RESOURCE_GROUP" --name "$DEPLOYMENT_NAME" --query properties.outputs.aksClusterName.value --output tsv)
ACR_LOGIN_SERVER=$(az deployment group show --resource-group "$RESOURCE_GROUP" --name "$DEPLOYMENT_NAME" --query properties.outputs.acrLoginServer.value --output tsv)
APPNET_NAME=$(az deployment group show --resource-group "$RESOURCE_GROUP" --name "$DEPLOYMENT_NAME" --query properties.outputs.appNetName.value --output tsv)
SAMPLE_APP_IMAGE_TAG=$(compute_sample_app_image_tag "$REPO_ROOT/shared/sample-app")
echo -e "${GREEN}✓ AKS Cluster: ${AKS_NAME}${NC}"
echo -e "${GREEN}✓ Application Network: ${APPNET_NAME}${NC}"
echo -e "${GREEN}✓ Image: ${ACR_LOGIN_SERVER}/${IMAGE_REPOSITORY}:${SAMPLE_APP_IMAGE_TAG}${NC}"
echo

echo -e "${YELLOW}[2/7] Getting AKS credentials...${NC}"
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_NAME" --overwrite-existing --output table
if [ -f ~/.kube/config ]; then
  chmod 600 ~/.kube/config
fi
echo -e "${GREEN}✓ AKS credentials configured${NC}"
echo

echo -e "${YELLOW}[3/7] Ensuring managed Gateway API and Application Network membership...${NC}"
az aks enable-gateway-api --resource-group "$RESOURCE_GROUP" --name "$AKS_NAME" --output table 2>/dev/null || \
  echo -e "${YELLOW}⚠ az aks enable-gateway-api did not run. Continuing because Gateway API may already be enabled by Bicep or the installed CLI may not expose the command.${NC}"
az appnet member show --resource-group "$RESOURCE_GROUP" --appnet-name "$APPNET_NAME" --member-name "$AKS_NAME" --output table 2>/dev/null || \
  echo -e "${YELLOW}⚠ Could not read Application Network membership with az appnet. Validate it in Azure if ambient resources are not created.${NC}"
for _ in {1..30}; do
  if kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1; then
    break
  fi
  echo -n "."
  sleep 5
done
echo
GATEWAY_CLASS_NAME=$(select_gateway_class)
echo -e "${GREEN}✓ Gateway API ready; using GatewayClass '${GATEWAY_CLASS_NAME}'${NC}"
echo

echo -e "${YELLOW}[4/7] Deploying ambient mesh application resources...${NC}"
cd "$SCRIPT_DIR/../kubernetes"
kubectl apply -f namespaces.yaml
apply_with_image frontend.yaml
apply_with_image orders.yaml
apply_with_image inventory.yaml
apply_gateway gateway.yaml
kubectl apply -f httproute.yaml
kubectl apply -f waypoint.yaml || echo -e "${YELLOW}⚠ Waypoint apply failed. Confirm that Application Network installed the Istio waypoint GatewayClass.${NC}"
kubectl apply -f telemetry.yaml || echo -e "${YELLOW}⚠ Telemetry apply failed. Confirm that telemetry.istio.io CRDs are available.${NC}"
echo -e "${GREEN}✓ Application resources applied${NC}"
echo

echo -e "${YELLOW}[5/7] Installing in-cluster Prometheus and Kiali...${NC}"
if command -v helm >/dev/null 2>&1; then
  kubectl apply -f kiali.yaml
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
  helm repo add kiali https://kiali.org/helm-charts >/dev/null
  helm repo update >/dev/null
  helm upgrade --install prometheus prometheus-community/prometheus \
    --namespace monitoring \
    --create-namespace \
    --set alertmanager.enabled=false \
    --set prometheus-pushgateway.enabled=false \
    --set server.persistentVolume.enabled=false \
    --wait \
    --timeout 5m
  helm upgrade --install kiali-server kiali/kiali-server \
    --namespace kiali-system \
    --create-namespace \
    --set auth.strategy=anonymous \
    --set external_services.prometheus.url=http://prometheus-server.monitoring.svc.cluster.local \
    --wait \
    --timeout 5m
  echo -e "${GREEN}✓ Prometheus and Kiali installed${NC}"
else
  echo -e "${YELLOW}⚠ Helm is not installed. Skipping Prometheus and Kiali installation.${NC}"
fi
echo

echo -e "${YELLOW}[6/7] Waiting for workloads...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/frontend -n "$APP_NAMESPACE"
kubectl wait --for=condition=available --timeout=300s deployment/orders -n "$APP_NAMESPACE"
kubectl wait --for=condition=available --timeout=300s deployment/inventory -n "$APP_NAMESPACE"
kubectl get pods,svc -n "$APP_NAMESPACE"
echo -e "${GREEN}✓ Workloads are available${NC}"
echo

echo -e "${YELLOW}[7/7] Waiting for external Gateway address (this may take 2-3 minutes)...${NC}"
for _ in {1..30}; do
  EXTERNAL_IP=$(kubectl get gateway mesh-demo-gateway -n "$APP_NAMESPACE" -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || echo "")
  if [ -n "$EXTERNAL_IP" ]; then
    break
  fi
  echo -n "."
  sleep 10
done
echo

if [ -z "$EXTERNAL_IP" ]; then
  echo -e "${YELLOW}⚠ External IP not yet assigned. Check: kubectl get gateway mesh-demo-gateway -n ${APP_NAMESPACE}${NC}"
else
  echo -e "${GREEN}✓ External IP assigned${NC}"
  echo
  echo -e "${GREEN}================================================${NC}"
  echo -e "${GREEN}  Deployment Complete!${NC}"
  echo -e "${GREEN}================================================${NC}"
  echo
  echo -e "Application URL: ${GREEN}http://${EXTERNAL_IP}${NC}"
  echo "Health Check: http://${EXTERNAL_IP}/health"
  echo "API Info: http://${EXTERNAL_IP}/api/info"
  echo "Traffic Chain: http://${EXTERNAL_IP}/api/call"
fi

echo
echo "Useful commands:"
echo "  ./scripts/generate-traffic.sh"
echo "  ./scripts/validate-demo.sh"
echo "  kubectl port-forward -n kiali-system svc/kiali 20001:20001"
echo "  kubectl get gateway,httproute -A"
echo "  kubectl get pods -n ${APP_NAMESPACE} --show-labels"
echo
