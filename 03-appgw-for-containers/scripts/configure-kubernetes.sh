#!/bin/bash
set -e
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}  Application Gateway for Containers - Kubernetes Configuration${NC}"
echo -e "${GREEN}================================================================${NC}"
echo

RESOURCE_GROUP="rg-03-appgw-containers-demo"
DEPLOYMENT_NAME="appgw-demo-deployment"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
IMAGE_REPOSITORY="aks-ingress-demo"
source "$REPO_ROOT/shared/scripts/acr-image.sh"

command -v az >/dev/null 2>&1 || { echo -e "${RED}Azure CLI is required but not installed.${NC}" >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}kubectl is required but not installed.${NC}" >&2; exit 1; }

echo -e "${YELLOW}[1/5] Reading infrastructure outputs...${NC}"
AKS_NAME=$(az deployment group show --resource-group $RESOURCE_GROUP --name $DEPLOYMENT_NAME --query properties.outputs.aksClusterName.value --output tsv)
ACR_LOGIN_SERVER=$(az deployment group show --resource-group $RESOURCE_GROUP --name $DEPLOYMENT_NAME --query properties.outputs.acrLoginServer.value --output tsv)
APPGW_SUBNET_ID=$(az deployment group show --resource-group $RESOURCE_GROUP --name $DEPLOYMENT_NAME --query properties.outputs.appgwSubnetId.value --output tsv)
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

echo -e "${YELLOW}[3/5] Configuring Application Gateway for Containers...${NC}"
echo "Waiting for ALB Controller deployment..."
ALB_CONTROLLER_READY=false
for _ in {1..30}; do
  if kubectl get deployment/alb-controller -n kube-system >/dev/null 2>&1; then
    ALB_CONTROLLER_READY=true
    break
  fi
  echo -n "."
  sleep 10
done
echo
if [ "$ALB_CONTROLLER_READY" != "true" ]; then
  echo -e "${RED}ALB Controller deployment was not created by the AKS Web App Routing add-on.${NC}" >&2
  echo "Check add-on state with:"
  echo "  az aks show -g $RESOURCE_GROUP -n $AKS_NAME --query ingressProfile.webAppRouting"
  echo "Recent kube-system resources:"
  kubectl get pods,deployments -n kube-system | grep -Ei 'alb|app-routing|webapp|gateway' || true
  exit 1
fi
kubectl wait --for=condition=available --timeout=300s deployment/alb-controller -n kube-system

echo "Waiting for ApplicationLoadBalancer CRD..."
ALB_CRD_READY=false
for _ in {1..30}; do
  if kubectl get crd applicationloadbalancers.alb.networking.azure.io >/dev/null 2>&1; then
    ALB_CRD_READY=true
    break
  fi
  echo -n "."
  sleep 10
done
echo
if [ "$ALB_CRD_READY" != "true" ]; then
  echo -e "${RED}ApplicationLoadBalancer CRD was not installed by the ALB Controller.${NC}" >&2
  kubectl get crd | grep -i alb || true
  exit 1
fi
kubectl wait --for=condition=Established --timeout=300s crd/applicationloadbalancers.alb.networking.azure.io
cat <<EOF | kubectl apply -f -
apiVersion: alb.networking.azure.io/v1
kind: ApplicationLoadBalancer
metadata:
  name: alb-controller
  namespace: kube-system
spec:
  associations:
  - $APPGW_SUBNET_ID
EOF
kubectl get applicationloadbalancer -n kube-system alb-controller
echo -e "${GREEN}✓ Application Gateway for Containers configured${NC}"
echo

echo -e "${YELLOW}[4/5] Deploying application...${NC}"
cd "$SCRIPT_DIR/../kubernetes"
sed -e "s|\${ACR_LOGIN_SERVER}|${ACR_LOGIN_SERVER}|g" -e "s|\${IMAGE_TAG}|${SAMPLE_APP_IMAGE_TAG}|g" deployment.yaml | kubectl apply -f -
kubectl apply -f service.yaml
kubectl apply -f gateway.yaml
kubectl apply -f httproute.yaml
echo -e "${GREEN}✓ Application deployed${NC}"
echo

echo -e "${YELLOW}[5/5] Waiting for external IP (this may take 2-3 minutes)...${NC}"
for _ in {1..40}; do
  EXTERNAL_IP=$(kubectl get gateway appgw-demo-gateway -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || echo "")
  if [ -n "$EXTERNAL_IP" ]; then
    break
  fi
  echo -n "."
  sleep 10
done
echo

if [ -z "$EXTERNAL_IP" ]; then
  echo -e "${RED}⚠ Warning: External IP not yet assigned. Check status with:${NC}"
  echo -e "  kubectl get gateway appgw-demo-gateway"
  echo -e "  kubectl describe gateway appgw-demo-gateway"
else
  echo -e "${GREEN}✓ External IP assigned${NC}"
  echo
  echo -e "${GREEN}================================================================${NC}"
  echo -e "${GREEN}  Deployment Complete!${NC}"
  echo -e "${GREEN}================================================================${NC}"
  echo
  echo -e "Application URL: ${GREEN}http://${EXTERNAL_IP}${NC}"
  echo
  echo "Health Check: http://${EXTERNAL_IP}/health"
  echo "API Info: http://${EXTERNAL_IP}/api/info"
  echo
  echo -e "${YELLOW}Note: It may take 30-60 seconds for the application to become fully available.${NC}"
  echo
  echo "To view resources:"
  echo "  kubectl get all"
  echo "  kubectl get gateway"
  echo "  kubectl get httproute"
  echo "  kubectl get applicationloadbalancer -n kube-system"
  echo
  echo "To view logs:"
  echo "  kubectl logs -l app=appgw-demo-app"
  echo
  echo "To view Gateway status:"
  echo "  kubectl describe gateway appgw-demo-gateway"
  echo
  echo "To clean up:"
  echo "  ./scripts/cleanup.sh"
fi
