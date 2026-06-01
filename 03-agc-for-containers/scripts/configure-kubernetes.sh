#!/bin/bash
set -e
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}  AGC - Kubernetes Configuration${NC}"
echo -e "${GREEN}================================================================${NC}"
echo

RESOURCE_GROUP="rg-03-agc-containers-demo"
DEPLOYMENT_NAME="agc-demo-deployment"
APP_NAMESPACE="demo"
ALB_CONTROLLER_NAMESPACE="azure-alb-system"
ALB_RESOURCE_NAMESPACE="alb-infra"
ALB_RESOURCE_NAME="alb"
APPLICATIONLOADBALANCER_CRD="applicationloadbalancer.alb.networking.azure.io"
WAF_POLICY_CRD="webapplicationfirewallpolicy.alb.networking.azure.io"
ALB_HELM_VERSION="1.10.28"
FEDERATED_IDENTITY_NAME="alb-controller"
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
AGC_SUBNET_ID=$(az deployment group show --resource-group $RESOURCE_GROUP --name $DEPLOYMENT_NAME --query properties.outputs.agcSubnetId.value --output tsv)
OIDC_ISSUER_URL=$(az deployment group show --resource-group $RESOURCE_GROUP --name $DEPLOYMENT_NAME --query properties.outputs.oidcIssuerUrl.value --output tsv)
AGC_IDENTITY_NAME=$(az deployment group show --resource-group $RESOURCE_GROUP --name $DEPLOYMENT_NAME --query properties.outputs.agcIdentityName.value --output tsv)
AGC_IDENTITY_CLIENT_ID=$(az deployment group show --resource-group $RESOURCE_GROUP --name $DEPLOYMENT_NAME --query properties.outputs.agcIdentityClientId.value --output tsv)
WAF_POLICY_ID=$(az deployment group show --resource-group $RESOURCE_GROUP --name $DEPLOYMENT_NAME --query properties.outputs.wafPolicyId.value --output tsv)
SAMPLE_APP_IMAGE_TAG=$(compute_sample_app_image_tag "$REPO_ROOT/shared/sample-app")
echo -e "${GREEN}✓ AKS Cluster: ${AKS_NAME}${NC}"
echo -e "${GREEN}✓ Image: ${ACR_LOGIN_SERVER}/${IMAGE_REPOSITORY}:${SAMPLE_APP_IMAGE_TAG}${NC}"
echo -e "${GREEN}✓ WAF Policy: ${WAF_POLICY_ID}${NC}"
echo

echo -e "${YELLOW}[2/5] Getting AKS credentials...${NC}"
az aks get-credentials --resource-group $RESOURCE_GROUP --name "$AKS_NAME" --overwrite-existing --output table
if [ -f ~/.kube/config ]; then
  chmod 600 ~/.kube/config
fi
echo -e "${GREEN}✓ AKS credentials configured${NC}"
echo

echo -e "${YELLOW}[3/5] Configuring Application Gateway for Containers...${NC}"
echo "Configuring Workload Identity federation for ALB Controller..."
if az identity federated-credential show \
  --resource-group "$RESOURCE_GROUP" \
  --identity-name "$AGC_IDENTITY_NAME" \
  --name "$FEDERATED_IDENTITY_NAME" >/dev/null 2>&1; then
  echo "Federated credential already exists"
else
  az identity federated-credential create \
    --resource-group "$RESOURCE_GROUP" \
    --identity-name "$AGC_IDENTITY_NAME" \
    --name "$FEDERATED_IDENTITY_NAME" \
    --issuer "$OIDC_ISSUER_URL" \
    --subject "system:serviceaccount:${ALB_CONTROLLER_NAMESPACE}:alb-controller-sa" \
    --output none
fi

echo "Installing ALB Controller with Helm..."
helm upgrade --install alb-controller oci://mcr.microsoft.com/application-lb/charts/alb-controller \
  --namespace "$ALB_CONTROLLER_NAMESPACE" \
  --create-namespace \
  --version "$ALB_HELM_VERSION" \
  --set albController.namespace="$ALB_CONTROLLER_NAMESPACE" \
  --set albController.podIdentity.clientID="$AGC_IDENTITY_CLIENT_ID" \
  --wait \
  --timeout 10m

echo "Waiting for ALB Controller deployment..."
ALB_CONTROLLER_READY=false
for _ in {1..30}; do
  if kubectl get deployment/alb-controller -n "$ALB_CONTROLLER_NAMESPACE" >/dev/null 2>&1; then
    ALB_CONTROLLER_READY=true
    break
  fi
  echo -n "."
  sleep 10
done
echo
if [ "$ALB_CONTROLLER_READY" != "true" ]; then
  echo -e "${RED}ALB Controller deployment was not created by the Helm chart.${NC}" >&2
  echo "Recent ALB Controller resources:"
  kubectl get all -n "$ALB_CONTROLLER_NAMESPACE" || true
  exit 1
fi
kubectl wait --for=condition=available --timeout=300s deployment/alb-controller -n "$ALB_CONTROLLER_NAMESPACE"

echo "Waiting for ApplicationLoadBalancer CRD..."
ALB_CRD_READY=false
for _ in {1..30}; do
  if kubectl get crd "$APPLICATIONLOADBALANCER_CRD" >/dev/null 2>&1; then
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
kubectl wait --for=condition=Established --timeout=300s "crd/$APPLICATIONLOADBALANCER_CRD"
kubectl wait --for=condition=Established --timeout=300s "crd/$WAF_POLICY_CRD"

kubectl create namespace "$ALB_RESOURCE_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
cat <<EOF | kubectl apply -f -
apiVersion: alb.networking.azure.io/v1
kind: ApplicationLoadBalancer
metadata:
  name: $ALB_RESOURCE_NAME
  namespace: $ALB_RESOURCE_NAMESPACE
spec:
  associations:
  - $AGC_SUBNET_ID
EOF
kubectl get applicationloadbalancer -n "$ALB_RESOURCE_NAMESPACE" "$ALB_RESOURCE_NAME"

echo "Waiting for Application Gateway for Containers resource to become ready (this may take 5-6 minutes)..."
ALB_DEPLOYMENT_READY=false
for _ in {1..60}; do
  ALB_DEPLOYMENT_REASON=$(kubectl get applicationloadbalancer -n "$ALB_RESOURCE_NAMESPACE" "$ALB_RESOURCE_NAME" -o jsonpath='{range .status.conditions[?(@.type=="Deployment")]}{.reason}{end}' 2>/dev/null || echo "")
  if [ "$ALB_DEPLOYMENT_REASON" = "Ready" ]; then
    ALB_DEPLOYMENT_READY=true
    break
  fi
  echo -n "."
  sleep 10
done
echo

if [ "$ALB_DEPLOYMENT_READY" != "true" ]; then
  echo -e "${RED}Application Gateway for Containers did not become ready in time.${NC}" >&2
  kubectl get applicationloadbalancer -n "$ALB_RESOURCE_NAMESPACE" "$ALB_RESOURCE_NAME" -o yaml
  exit 1
fi

echo -e "${GREEN}✓ Application Gateway for Containers configured${NC}"
echo

echo -e "${YELLOW}[4/5] Deploying application...${NC}"
cd "$SCRIPT_DIR/../kubernetes"
kubectl apply -f namespace.yaml
sed -e "s|\${ACR_LOGIN_SERVER}|${ACR_LOGIN_SERVER}|g" -e "s|\${IMAGE_TAG}|${SAMPLE_APP_IMAGE_TAG}|g" deployment.yaml | kubectl apply -f -
kubectl apply -f service.yaml
kubectl apply -f gateway.yaml
kubectl apply -f httproute.yaml
sed -e "s|\${WAF_POLICY_ID}|${WAF_POLICY_ID}|g" waf-policy.yaml | kubectl apply -f -
echo -e "${GREEN}✓ Application deployed${NC}"
echo

echo -e "${YELLOW}[5/5] Waiting for external IP (this may take 2-3 minutes)...${NC}"
for _ in {1..40}; do
  EXTERNAL_IP=$(kubectl get gateway agc-demo-gateway -n "$APP_NAMESPACE" -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || echo "")
  if [ -n "$EXTERNAL_IP" ]; then
    break
  fi
  echo -n "."
  sleep 10
done
echo

if [ -z "$EXTERNAL_IP" ]; then
  echo -e "${RED}⚠ Warning: External IP not yet assigned. Check status with:${NC}"
  echo -e "  kubectl get gateway agc-demo-gateway -n $APP_NAMESPACE"
  echo -e "  kubectl describe gateway agc-demo-gateway -n $APP_NAMESPACE"
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
  echo "  kubectl get all -n $APP_NAMESPACE"
  echo "  kubectl get gateway -n $APP_NAMESPACE"
  echo "  kubectl get httproute -n $APP_NAMESPACE"
  echo "  kubectl get webapplicationfirewallpolicy -n $APP_NAMESPACE"
  echo "  kubectl get applicationloadbalancer -n $ALB_RESOURCE_NAMESPACE"
  echo
  echo "To view logs:"
  echo "  kubectl logs -n $APP_NAMESPACE -l app=agc-demo-app"
  echo
  echo "To view Gateway status:"
  echo "  kubectl describe gateway agc-demo-gateway -n $APP_NAMESPACE"
  echo
  echo "To view WAF status:"
  echo "  kubectl describe webapplicationfirewallpolicy agc-demo-waf-policy -n $APP_NAMESPACE"
  echo
  echo "To clean up:"
  echo "  ./scripts/cleanup.sh"
fi
