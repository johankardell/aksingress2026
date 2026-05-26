#!/bin/bash
set -e
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  Gateway API with Envoy - Deployment Script${NC}"
echo -e "${GREEN}================================================${NC}"
echo

# Variables
RESOURCE_GROUP="rg-02-envoy-gateway-demo"
LOCATION="swedencentral"
DEPLOYMENT_NAME="envoy-demo-deployment"

delete_role_assignments() {
  local assignee="$1"
  local role="$2"
  local scope="$3"

  if [ -z "$assignee" ] || [ -z "$scope" ]; then
    return
  fi

  local assignment_ids
  assignment_ids=$(az role assignment list \
    --assignee "$assignee" \
    --role "$role" \
    --scope "$scope" \
    --query "[].id" \
    --output tsv 2>/dev/null || true)

  if [ -z "$assignment_ids" ]; then
    return
  fi

  echo "$assignment_ids" | while IFS= read -r assignment_id; do
    if [ -n "$assignment_id" ]; then
      echo "Removing existing '$role' role assignment at scope: $scope"
      az role assignment delete --ids "$assignment_id" --output none
    fi
  done
}

cleanup_conflicting_role_assignments() {
  echo -e "${YELLOW}Role assignment already exists. Cleaning known conflicting assignments and retrying...${NC}"

  local aks_name acr_name aks_id acr_id kubelet_object_id
  aks_name=$(az aks list --resource-group "$RESOURCE_GROUP" --query "[0].name" --output tsv 2>/dev/null || true)
  acr_name=$(az acr list --resource-group "$RESOURCE_GROUP" --query "[0].name" --output tsv 2>/dev/null || true)

  if [ -n "$aks_name" ]; then
    aks_id=$(az aks show --resource-group "$RESOURCE_GROUP" --name "$aks_name" --query id --output tsv 2>/dev/null || true)
    kubelet_object_id=$(az aks show --resource-group "$RESOURCE_GROUP" --name "$aks_name" --query identityProfile.kubeletidentity.objectId --output tsv 2>/dev/null || true)
  fi

  if [ -n "$acr_name" ]; then
    acr_id=$(az acr show --resource-group "$RESOURCE_GROUP" --name "$acr_name" --query id --output tsv 2>/dev/null || true)
  fi

  delete_role_assignments "$kubelet_object_id" "AcrPull" "$acr_id"
  delete_role_assignments "$USER_OBJECT_ID" "Azure Kubernetes Service Cluster User Role" "$aks_id"
  delete_role_assignments "$USER_OBJECT_ID" "Azure Kubernetes Service RBAC Cluster Admin" "$aks_id"
}

deploy_infrastructure() {
  local output_file
  output_file=$(mktemp)

  if az deployment group create \
    --resource-group $RESOURCE_GROUP \
    --name $DEPLOYMENT_NAME \
    --template-file main.bicep \
    --parameters main.bicepparam \
    --parameters userObjectId=$USER_OBJECT_ID \
    --output table 2>&1 | tee "$output_file"; then
    rm -f "$output_file"
    return
  fi

  if grep -q "RoleAssignmentExists" "$output_file"; then
    cleanup_conflicting_role_assignments
    rm -f "$output_file"
    az deployment group create \
      --resource-group $RESOURCE_GROUP \
      --name $DEPLOYMENT_NAME \
      --template-file main.bicep \
      --parameters main.bicepparam \
      --parameters userObjectId=$USER_OBJECT_ID \
      --output table
  else
    rm -f "$output_file"
    return 1
  fi
}

# Check prerequisites
echo -e "${YELLOW}[1/10] Checking prerequisites...${NC}"
command -v az >/dev/null 2>&1 || { echo -e "${RED}Azure CLI is required but not installed.${NC}" >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}kubectl is required but not installed.${NC}" >&2; exit 1; }
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
echo -e "${GREEN}✓ Resource providers registered${NC}"
echo

# Create resource group
echo -e "${YELLOW}[3/10] Creating resource group...${NC}"
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION \
  --output table
echo -e "${GREEN}✓ Resource group created${NC}"
echo

# Get current user object ID for RBAC
echo -e "${YELLOW}[4/10] Getting user information for RBAC...${NC}"
USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
echo -e "${GREEN}✓ User Object ID: ${USER_OBJECT_ID}${NC}"
echo

# Get script directory early for later use
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"

# Deploy infrastructure
echo -e "${YELLOW}[5/10] Deploying infrastructure (this may take 5-10 minutes)...${NC}"
cd "$SCRIPT_DIR/../infrastructure"
deploy_infrastructure

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

echo -e "${GREEN}✓ Infrastructure deployed${NC}"
echo -e "  AKS Cluster: ${AKS_NAME}"
echo -e "  ACR: ${ACR_NAME}"
echo

# Get AKS credentials using Entra ID and Azure RBAC
echo -e "${YELLOW}[6/10] Getting AKS credentials...${NC}"
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_NAME \
  --overwrite-existing \
  --output table

# Fix kubeconfig permissions
if [ -f ~/.kube/config ]; then
  chmod 600 ~/.kube/config
fi

echo -e "${GREEN}✓ AKS credentials configured${NC}"
echo

# Build and push container image using Azure Container Registry Tasks
echo -e "${YELLOW}[7/10] Building container image with ACR Tasks...${NC}"
cd "$REPO_ROOT/shared/sample-app"
az acr build \
  --registry $ACR_NAME \
  --image aks-ingress-demo:latest \
  --image aks-ingress-demo:envoy-v1.0.0 \
  --file Dockerfile \
  . \
  --output table
echo -e "${GREEN}✓ Container image built and pushed by ACR Tasks${NC}"
echo

# Install Envoy Gateway
echo -e "${YELLOW}[8/10] Installing Envoy Gateway (stable release)...${NC}"

# Use a specific stable version instead of 'latest'
ENVOY_GATEWAY_VERSION="v1.2.3"
echo "Installing Envoy Gateway ${ENVOY_GATEWAY_VERSION}..."

# Install Envoy Gateway with server-side apply
kubectl apply --server-side --force-conflicts -f "https://github.com/envoyproxy/gateway/releases/download/${ENVOY_GATEWAY_VERSION}/install.yaml"

echo "Waiting for Envoy Gateway deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/envoy-gateway -n envoy-gateway-system || {
  echo -e "${YELLOW}⚠ Deployment not ready yet, checking pod status...${NC}"
  kubectl get pods -n envoy-gateway-system
  kubectl logs -n envoy-gateway-system deployment/envoy-gateway --tail=20 || true
}

# Verify GatewayClass was created
echo -e "${YELLOW}Verifying GatewayClass...${NC}"
for i in {1..30}; do
  if kubectl get gatewayclass envoy-gateway >/dev/null 2>&1; then
    echo -e "${GREEN}✓ GatewayClass 'envoy-gateway' is available${NC}"
    break
  fi
  echo -n "."
  sleep 2
done
echo

# Show GatewayClass status
kubectl get gatewayclass envoy-gateway -o wide 2>/dev/null || {
  echo -e "${YELLOW}⚠ GatewayClass not found, creating it...${NC}"
  kubectl apply -f "$SCRIPT_DIR/../kubernetes/gatewayclass.yaml"
  sleep 5
}

kubectl describe gatewayclass envoy-gateway | grep -A 2 "Status:" || true
echo -e "${GREEN}✓ Envoy Gateway installed${NC}"
echo

# Deploy application
echo -e "${YELLOW}[9/10] Deploying application...${NC}"
cd "$SCRIPT_DIR/../kubernetes"

# Apply resources in order
kubectl apply -f gatewayclass.yaml 2>/dev/null || echo "GatewayClass already exists"
# Update deployment with ACR login server
sed "s|\${ACR_LOGIN_SERVER}|${ACR_LOGIN_SERVER}|g" deployment.yaml | kubectl apply -f -
kubectl apply -f service.yaml
kubectl apply -f gateway.yaml
kubectl apply -f httproute.yaml

echo -e "${GREEN}✓ Application deployed${NC}"
echo

# Wait for Gateway to get external IP
echo -e "${YELLOW}[10/10] Waiting for external IP (this may take 2-3 minutes)...${NC}"
for i in {1..30}; do
  EXTERNAL_IP=$(kubectl get gateway envoy-demo-gateway -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || echo "")
  if [ -n "$EXTERNAL_IP" ]; then
    break
  fi
  echo -n "."
  sleep 10
done
echo

if [ -z "$EXTERNAL_IP" ]; then
  echo -e "${RED}⚠ Warning: External IP not yet assigned. Check status with:${NC}"
  echo -e "  kubectl get gateway envoy-demo-gateway"
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
  echo "  kubectl get all"
  echo "  kubectl get gateway"
  echo "  kubectl get httproute"
  echo
  echo "To view logs:"
  echo "  kubectl logs -l app=envoy-demo-app"
  echo
  echo "To view Gateway status:"
  echo "  kubectl describe gateway envoy-demo-gateway"
  echo
  echo "To clean up:"
  echo "  ./scripts/cleanup.sh"
fi
