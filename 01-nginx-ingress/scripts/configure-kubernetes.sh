#!/bin/bash
set -e
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  NGINX Ingress Demo - Kubernetes Configuration${NC}"
echo -e "${GREEN}================================================${NC}"
echo

RESOURCE_GROUP="rg-01-nginx-ingress-demo"
DEPLOYMENT_NAME="nginx-demo-deployment"
NGINX_NAMESPACE="ingress-nginx"
APP_NAMESPACE="demo"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
IMAGE_REPOSITORY="aks-ingress-demo"
source "$REPO_ROOT/shared/scripts/acr-image.sh"

command -v az >/dev/null 2>&1 || { echo -e "${RED}Azure CLI is required but not installed.${NC}" >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}kubectl is required but not installed.${NC}" >&2; exit 1; }
command -v helm >/dev/null 2>&1 || { echo -e "${RED}Helm is required but not installed.${NC}" >&2; exit 1; }

echo -e "${YELLOW}[1/5] Reading infrastructure outputs...${NC}"
AKS_NAME=$(az deployment group show --resource-group $RESOURCE_GROUP --name $DEPLOYMENT_NAME --query properties.outputs.aksClusterName.value --output tsv)
ACR_LOGIN_SERVER=$(az deployment group show --resource-group $RESOURCE_GROUP --name $DEPLOYMENT_NAME --query properties.outputs.acrLoginServer.value --output tsv)
SAMPLE_APP_IMAGE_TAG=$(compute_sample_app_image_tag "$REPO_ROOT/shared/sample-app")
echo -e "${GREEN}✓ AKS Cluster: ${AKS_NAME}${NC}"
echo -e "${GREEN}✓ Image: ${ACR_LOGIN_SERVER}/${IMAGE_REPOSITORY}:${SAMPLE_APP_IMAGE_TAG}${NC}"
echo

echo -e "${YELLOW}[2/5] Getting AKS credentials...${NC}"
az aks get-credentials --resource-group $RESOURCE_GROUP --name "$AKS_NAME" --overwrite-existing --output table
if [ -f ~/.kube/config ]; then
  chmod 600 ~/.kube/config
fi
echo -e "${GREEN}✓ AKS credentials configured${NC}"
echo

echo -e "${YELLOW}[3/5] Installing NGINX Ingress Controller...${NC}"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx   --create-namespace   --namespace $NGINX_NAMESPACE   --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz   --set controller.service.externalTrafficPolicy=Local   --wait   --timeout 5m
echo -e "${GREEN}✓ NGINX Ingress Controller installed${NC}"
echo

echo -e "${YELLOW}[4/5] Deploying application...${NC}"
cd "$SCRIPT_DIR/../kubernetes"
kubectl apply -f namespace.yaml
sed -e "s|\${ACR_LOGIN_SERVER}|${ACR_LOGIN_SERVER}|g" -e "s|\${IMAGE_TAG}|${SAMPLE_APP_IMAGE_TAG}|g" deployment.yaml | kubectl apply -f -
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml
echo -e "${GREEN}✓ Application deployed${NC}"
echo

echo -e "${YELLOW}[5/5] Waiting for external IP (this may take 2-3 minutes)...${NC}"
for _ in {1..30}; do
  EXTERNAL_IP=$(kubectl get ingress nginx-demo-ingress -n "$APP_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
  if [ -n "$EXTERNAL_IP" ]; then
    break
  fi
  echo -n "."
  sleep 10
done
echo

if [ -z "$EXTERNAL_IP" ]; then
  echo -e "${RED}⚠ Warning: External IP not yet assigned. Check status with:${NC}"
  echo -e "  kubectl get ingress nginx-demo-ingress -n $APP_NAMESPACE"
else
  echo -e "${GREEN}✓ External IP assigned${NC}"
  echo
  echo -e "${GREEN}================================================${NC}"
  echo -e "${GREEN}  Deployment Complete!${NC}"
  echo -e "${GREEN}================================================${NC}"
  echo
  echo -e "Application URL: ${GREEN}http://${EXTERNAL_IP}${NC}"
  echo
  echo "Health Check: http://${EXTERNAL_IP}/health"
  echo "API Info: http://${EXTERNAL_IP}/api/info"
  echo
  echo -e "${YELLOW}Note: It may take 30-60 seconds for the application to become fully available.${NC}"
  echo
  echo "To view resources:"
  echo "  kubectl get all -n $APP_NAMESPACE"
  echo "  kubectl get ingress -n $APP_NAMESPACE"
  echo
  echo "To view logs:"
  echo "  kubectl logs -n $APP_NAMESPACE -l app=nginx-demo-app"
  echo
  echo "To clean up:"
  echo "  ./scripts/cleanup.sh"
fi
