#!/bin/bash
set -e
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}  AFD + AppGW - Kubernetes Configuration${NC}"
echo -e "${GREEN}================================================================${NC}"
echo

RESOURCE_GROUP="rg-05-afd-appgw-demo"
DEPLOYMENT_NAME="afd-appgw-demo-deployment"
APP_NAMESPACE="demo"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
IMAGE_REPOSITORY="aks-ingress-demo"
source "$REPO_ROOT/shared/scripts/acr-image.sh"

command -v az >/dev/null 2>&1 || { echo -e "${RED}Azure CLI is required but not installed.${NC}" >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}kubectl is required but not installed.${NC}" >&2; exit 1; }

echo -e "${YELLOW}[1/4] Reading infrastructure outputs...${NC}"
AKS_NAME=$(az deployment group show --resource-group $RESOURCE_GROUP --name $DEPLOYMENT_NAME --query properties.outputs.aksClusterName.value --output tsv)
ACR_LOGIN_SERVER=$(az deployment group show --resource-group $RESOURCE_GROUP --name $DEPLOYMENT_NAME --query properties.outputs.acrLoginServer.value --output tsv)
APP_GATEWAY_NAME=$(az deployment group show --resource-group $RESOURCE_GROUP --name $DEPLOYMENT_NAME --query properties.outputs.appGatewayName.value --output tsv)
APP_GATEWAY_PUBLIC_IP=$(az deployment group show --resource-group $RESOURCE_GROUP --name $DEPLOYMENT_NAME --query properties.outputs.appGatewayPublicIpAddress.value --output tsv)
FRONT_DOOR_ENDPOINT_HOSTNAME=$(az deployment group show --resource-group $RESOURCE_GROUP --name $DEPLOYMENT_NAME --query properties.outputs.frontDoorEndpointHostName.value --output tsv)
SAMPLE_APP_IMAGE_TAG=$(compute_sample_app_image_tag "$REPO_ROOT/shared/sample-app")
echo -e "${GREEN}✓ AKS Cluster: ${AKS_NAME}${NC}"
echo -e "${GREEN}✓ Application Gateway: ${APP_GATEWAY_NAME} (${APP_GATEWAY_PUBLIC_IP})${NC}"
echo -e "${GREEN}✓ Front Door Endpoint: ${FRONT_DOOR_ENDPOINT_HOSTNAME}${NC}"
echo -e "${GREEN}✓ Image: ${ACR_LOGIN_SERVER}/${IMAGE_REPOSITORY}:${SAMPLE_APP_IMAGE_TAG}${NC}"
echo

echo -e "${YELLOW}[2/4] Getting AKS credentials...${NC}"
az aks get-credentials --resource-group $RESOURCE_GROUP --name "$AKS_NAME" --overwrite-existing --output table
if [ -f ~/.kube/config ]; then
  chmod 600 ~/.kube/config
fi
echo -e "${GREEN}✓ AKS credentials configured${NC}"
echo

echo -e "${YELLOW}[3/4] Waiting for the Application Gateway Ingress Controller (AGIC) add-on...${NC}"
AGIC_READY=false
for _ in {1..30}; do
  if kubectl get pods -n kube-system -l app=ingress-appgw 2>/dev/null | grep -q Running; then
    AGIC_READY=true
    break
  fi
  echo -n "."
  sleep 10
done
echo
if [ "$AGIC_READY" != "true" ]; then
  echo -e "${RED}AGIC add-on pod was not observed running in kube-system.${NC}" >&2
  kubectl get pods -n kube-system -l app=ingress-appgw || true
  exit 1
fi
echo -e "${GREEN}✓ AGIC add-on is running${NC}"
echo

echo -e "${YELLOW}[4/4] Deploying application...${NC}"
cd "$SCRIPT_DIR/../kubernetes"
kubectl apply -f namespace.yaml
sed -e "s|\${ACR_LOGIN_SERVER}|${ACR_LOGIN_SERVER}|g" -e "s|\${IMAGE_TAG}|${SAMPLE_APP_IMAGE_TAG}|g" deployment.yaml | kubectl apply -f -
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml
echo -e "${GREEN}✓ Application deployed${NC}"
echo

echo "Waiting for AGIC to reconcile the Application Gateway (this may take 2-3 minutes)..."
INGRESS_READY=false
for _ in {1..30}; do
  INGRESS_IP=$(kubectl get ingress afd-appgw-demo-ingress -n "$APP_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
  if [ -n "$INGRESS_IP" ]; then
    INGRESS_READY=true
    break
  fi
  echo -n "."
  sleep 10
done
echo

if [ "$INGRESS_READY" != "true" ]; then
  echo -e "${RED}⚠ Warning: Ingress was not reconciled by AGIC yet. Check status with:${NC}"
  echo -e "  kubectl get ingress afd-appgw-demo-ingress -n $APP_NAMESPACE"
  echo -e "  kubectl describe ingress afd-appgw-demo-ingress -n $APP_NAMESPACE"
  echo -e "  kubectl logs -n kube-system -l app=ingress-appgw"
else
  echo -e "${GREEN}✓ Application Gateway backend pool updated by AGIC${NC}"
  echo
  echo -e "${GREEN}================================================================${NC}"
  echo -e "${GREEN}  Deployment Complete!${NC}"
  echo -e "${GREEN}================================================================${NC}"
  echo
  echo -e "Front Door Entry Point (recommended, WAF-protected): ${GREEN}https://${FRONT_DOOR_ENDPOINT_HOSTNAME}${NC}"
  echo -e "Application Gateway direct address (bypasses Front Door/WAF, for troubleshooting only): ${GREEN}http://${INGRESS_IP}${NC}"
  echo
  echo "Health Check: https://${FRONT_DOOR_ENDPOINT_HOSTNAME}/health"
  echo "API Info: https://${FRONT_DOOR_ENDPOINT_HOSTNAME}/api/info"
  echo
  echo -e "${YELLOW}Note: It may take a few minutes for Front Door's origin health probes to mark the Application Gateway origin healthy.${NC}"
  echo
  echo "To view resources:"
  echo "  kubectl get all -n $APP_NAMESPACE"
  echo "  kubectl get ingress -n $APP_NAMESPACE"
  echo "  az network application-gateway show --resource-group $RESOURCE_GROUP --name $APP_GATEWAY_NAME"
  echo "  az afd endpoint show --resource-group $RESOURCE_GROUP --profile-name <front-door-profile-name> --endpoint-name <endpoint-name>"
  echo
  echo "To view logs:"
  echo "  kubectl logs -n $APP_NAMESPACE -l app=afd-appgw-demo-app"
  echo "  kubectl logs -n kube-system -l app=ingress-appgw"
  echo
  echo "To clean up:"
  echo "  ./scripts/cleanup.sh"
fi
