#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}  Application Gateway for Containers - Deployment Script${NC}"
echo -e "${GREEN}================================================================${NC}"
echo

# Variables
RESOURCE_GROUP="rg-03-appgw-containers-demo"
LOCATION="swedencentral"
DEPLOYMENT_NAME="appgw-demo-deployment"

# Check prerequisites
echo -e "${YELLOW}[1/10] Checking prerequisites...${NC}"
command -v az >/dev/null 2>&1 || { echo -e "${RED}Azure CLI is required but not installed.${NC}" >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}kubectl is required but not installed.${NC}" >&2; exit 1; }
command -v docker >/dev/null 2>&1 || { echo -e "${RED}Docker is required but not installed.${NC}" >&2; exit 1; }
echo -e "${GREEN}✓ All prerequisites installed${NC}"
echo

# Register required Azure providers
echo -e "${YELLOW}[2/10] Registering Azure resource providers...${NC}"
echo "Registering Microsoft.ContainerService..."
az provider register --namespace Microsoft.ContainerService --wait 2>/dev/null || echo "Already registered"
echo "Registering Microsoft.OperationsManagement..."
az provider register --namespace Microsoft.OperationsManagement --wait 2>/dev/null || echo "Already registered"
echo "Registering Microsoft.ContainerRegistry..."
az provider register --namespace Microsoft.ContainerRegistry --wait 2>/dev/null || echo "Already registered"
echo "Registering Microsoft.Network..."
az provider register --namespace Microsoft.Network --wait 2>/dev/null || echo "Already registered"
echo "Registering Microsoft.ServiceNetworking..."
az provider register --namespace Microsoft.ServiceNetworking --wait 2>/dev/null || echo "Already registered"
echo -e "${GREEN}✓ Resource providers registered${NC}"
echo

# Check if Application Gateway for Containers extension is registered
echo -e "${YELLOW}[3/10] Checking Application Gateway for Containers provider...${NC}"
ALB_REGISTERED=$(az provider show --namespace Microsoft.ServiceNetworking --query "registrationState" -o tsv 2>/dev/null || echo "NotRegistered")
if [ "$ALB_REGISTERED" != "Registered" ]; then
  echo -e "${YELLOW}Microsoft.ServiceNetworking provider is not registered. Registering now...${NC}"
  az provider register --namespace Microsoft.ServiceNetworking --wait
  echo -e "${GREEN}✓ Provider registered${NC}"
else
  echo -e "${GREEN}✓ Provider already registered${NC}"
fi
echo

echo -e "${GREEN}✓ All prerequisites installed${NC}"
echo

# Create resource group
echo -e "${YELLOW}[4/10] Creating resource group...${NC}"
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION \
  --output table
echo -e "${GREEN}✓ Resource group created${NC}"
echo

# Get current user object ID for RBAC
echo -e "${YELLOW}[5/10] Getting user information for RBAC...${NC}"
USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
if [ -z "$USER_OBJECT_ID" ]; then
  echo -e "${RED}Failed to retrieve signed-in user Object ID.${NC}" >&2
  exit 1
fi
echo -e "${GREEN}✓ User Object ID: ${USER_OBJECT_ID}${NC}"
echo

# Get script directory early for later use
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"

# Deploy infrastructure
echo -e "${YELLOW}[6/10] Deploying infrastructure (this may take 5-10 minutes)...${NC}"
cd "$SCRIPT_DIR/../infrastructure"
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --name $DEPLOYMENT_NAME \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --parameters userObjectId=$USER_OBJECT_ID \
  --output table

# Get deployment outputs
AKS_NAME=$(az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name $DEPLOYMENT_NAME \
  --query properties.outputs.aksClusterName.value \
  --output tsv)

ACR_NAME=$(az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name $DEPLOYMENT_NAME \
  --query properties.outputs.acrName.value \
  --output tsv)

ACR_LOGIN_SERVER=$(az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name $DEPLOYMENT_NAME \
  --query properties.outputs.acrLoginServer.value \
  --output tsv)

APPGW_SUBNET_ID=$(az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name $DEPLOYMENT_NAME \
  --query properties.outputs.appgwSubnetId.value \
  --output tsv)

AGC_IDENTITY_CLIENT_ID=$(az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name $DEPLOYMENT_NAME \
  --query properties.outputs.agcIdentityClientId.value \
  --output tsv)

echo -e "${GREEN}✓ Infrastructure deployed${NC}"
echo -e "  AKS Cluster: ${AKS_NAME}"
echo -e "  ACR: ${ACR_NAME}"
echo

# Get AKS credentials (using admin credentials for deployment)
echo -e "${YELLOW}[7/10] Getting AKS credentials...${NC}"
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_NAME \
  --admin \
  --overwrite-existing \
  --output table

# Fix kubeconfig permissions
if [ -f ~/.kube/config ]; then
  chmod 600 ~/.kube/config
fi

echo -e "${GREEN}✓ Admin credentials configured${NC}"
echo

# Build and push Docker image
echo -e "${YELLOW}[8/10] Building and pushing Docker image...${NC}"
cd "$REPO_ROOT/shared/sample-app"
az acr build \
  --registry $ACR_NAME \
  --image aks-ingress-demo:latest \
  --image aks-ingress-demo:appgw-v1.0.0 \
  --file Dockerfile \
  . \
  --output table
echo -e "${GREEN}✓ Docker image built and pushed${NC}"
echo

# Update deployment with ACR login server
sed "s|\${ACR_LOGIN_SERVER}|${ACR_LOGIN_SERVER}|g" deployment.yaml | kubectl apply -f -
kubectl apply -f service.yaml
kubectl apply -f gateway.yaml
kubectl apply -f httproute.yaml

echo -e "${GREEN}✓ Application deployed${NC}"
echo

# Wait for Gateway to get external IP
echo -e "${YELLOW}[11/11] Waiting for external IP (this may take 2-3 minutes)...${NC}"
for i in {1..40}; do
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
