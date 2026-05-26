#!/bin/bash
set -e
set -o pipefail

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

  local aks_name acr_name aks_id acr_id kubelet_object_id vnet_id agc_identity_principal_id
  aks_name=$(az aks list --resource-group "$RESOURCE_GROUP" --query "[0].name" --output tsv 2>/dev/null || true)
  acr_name=$(az acr list --resource-group "$RESOURCE_GROUP" --query "[0].name" --output tsv 2>/dev/null || true)
  vnet_id=$(az network vnet list --resource-group "$RESOURCE_GROUP" --query "[0].id" --output tsv 2>/dev/null || true)
  agc_identity_principal_id=$(az identity list --resource-group "$RESOURCE_GROUP" --query "[0].principalId" --output tsv 2>/dev/null || true)

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
  delete_role_assignments "$agc_identity_principal_id" "Network Contributor" "$vnet_id"
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
echo -e "${YELLOW}[1/11] Checking prerequisites...${NC}"
command -v az >/dev/null 2>&1 || { echo -e "${RED}Azure CLI is required but not installed.${NC}" >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}kubectl is required but not installed.${NC}" >&2; exit 1; }
echo -e "${GREEN}✓ All prerequisites installed${NC}"
echo

# Register required Azure providers
echo -e "${YELLOW}[2/11] Registering Azure resource providers...${NC}"
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
echo -e "${YELLOW}[3/11] Checking Application Gateway for Containers provider...${NC}"
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
echo -e "${YELLOW}[4/11] Creating resource group...${NC}"
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION \
  --output table
echo -e "${GREEN}✓ Resource group created${NC}"
echo

# Get current user object ID for RBAC
echo -e "${YELLOW}[5/11] Getting user information for RBAC...${NC}"
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
IMAGE_REPOSITORY="aks-ingress-demo"
source "$REPO_ROOT/shared/scripts/acr-image.sh"

# Deploy infrastructure
echo -e "${YELLOW}[6/11] Deploying infrastructure (this may take 5-10 minutes)...${NC}"
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
echo -e "${YELLOW}[7/11] Getting AKS credentials...${NC}"
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

# Configure Application Gateway for Containers
echo -e "${YELLOW}[8/11] Configuring Application Gateway for Containers...${NC}"
echo "Waiting for ALB Controller deployment..."
ALB_CONTROLLER_READY=false
for i in {1..30}; do
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
for i in {1..30}; do
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

# Build and push container image using Azure Container Registry Tasks when needed
echo -e "${YELLOW}[9/11] Ensuring container image exists in ACR...${NC}"
ensure_sample_app_image "$ACR_NAME" "$REPO_ROOT/shared/sample-app" "$IMAGE_REPOSITORY"
echo -e "${GREEN}✓ Container image is available in ACR${NC}"
echo

# Update deployment with ACR login server
echo -e "${YELLOW}[10/11] Deploying application...${NC}"
cd "$SCRIPT_DIR/../kubernetes"
sed -e "s|\${ACR_LOGIN_SERVER}|${ACR_LOGIN_SERVER}|g" -e "s|\${IMAGE_TAG}|${SAMPLE_APP_IMAGE_TAG}|g" deployment.yaml | kubectl apply -f -
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
