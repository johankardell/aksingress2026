#!/bin/bash
set -e
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  AGC - Infrastructure Deployment${NC}"
echo -e "${GREEN}================================================${NC}"
echo

RESOURCE_GROUP="rg-03-agc-containers-demo"
LOCATION="swedencentral"
DEPLOYMENT_NAME="agc-demo-deployment"
AGC_CONFIG_MANAGER_ROLE_ID="fbc52c3f-28ad-4303-a892-8a056630b8f1"
NETWORK_CONTRIBUTOR_ROLE_ID="4d97b98b-1d4f-4787-a291-c67834d212e7"
READER_ROLE_ID="acdd72a7-3385-48ef-bd42-f606fba81ae7"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

command -v az >/dev/null 2>&1 || { echo -e "${RED}Azure CLI is required but not installed.${NC}" >&2; exit 1; }

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
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --template-file main.bicep \
    --parameters main.bicepparam \
    --parameters userObjectId="$USER_OBJECT_ID" \
    --output table 2>&1 | tee "$output_file"; then
    rm -f "$output_file"
    return
  fi

  if grep -q "RoleAssignmentExists" "$output_file"; then
    cleanup_conflicting_role_assignments
    rm -f "$output_file"
    az deployment group create \
      --resource-group "$RESOURCE_GROUP" \
      --name "$DEPLOYMENT_NAME" \
      --template-file main.bicep \
      --parameters main.bicepparam \
      --parameters userObjectId="$USER_OBJECT_ID" \
      --output table
  else
    rm -f "$output_file"
    return 1
  fi
}

ensure_role_assignment() {
  local principal_id="$1"
  local principal_type="$2"
  local role_id="$3"
  local scope="$4"
  local description="$5"

  if [ -z "$principal_id" ] || [ -z "$scope" ]; then
    echo -e "${RED}Cannot assign $description because principal or scope is empty.${NC}" >&2
    exit 1
  fi

  local existing_count
  existing_count=$(az role assignment list \
    --assignee "$principal_id" \
    --role "$role_id" \
    --scope "$scope" \
    --query "length(@)" \
    --output tsv 2>/dev/null || echo "0")

  if [ "$existing_count" != "0" ]; then
    echo "Role assignment already exists: $description"
    return
  fi

  echo "Creating role assignment: $description"
  for attempt in {1..6}; do
    if az role assignment create \
      --assignee-object-id "$principal_id" \
      --assignee-principal-type "$principal_type" \
      --role "$role_id" \
      --scope "$scope" \
      --output none; then
      return
    fi

    if [ "$attempt" -eq 6 ]; then
      echo -e "${RED}Failed to create role assignment after multiple attempts: $description${NC}" >&2
      exit 1
    fi

    echo "Role assignment failed, waiting for identity propagation before retry..."
    sleep 20
  done
}

echo -e "${YELLOW}[1/6] Registering Azure resource providers...${NC}"
echo "Registering Microsoft.ContainerService..."
az provider register --namespace Microsoft.ContainerService --wait 2>/dev/null || echo "Already registered"
echo "Registering Microsoft.OperationsManagement..."
az provider register --namespace Microsoft.OperationsManagement --wait 2>/dev/null || echo "Already registered"
echo "Registering Microsoft.ContainerRegistry..."
az provider register --namespace Microsoft.ContainerRegistry --wait 2>/dev/null || echo "Already registered"
echo "Registering Microsoft.Network..."
az provider register --namespace Microsoft.Network --wait 2>/dev/null || echo "Already registered"
echo "Registering Microsoft.NetworkFunction..."
az provider register --namespace Microsoft.NetworkFunction --wait 2>/dev/null || echo "Already registered"
echo "Registering Microsoft.ServiceNetworking..."
az provider register --namespace Microsoft.ServiceNetworking --wait 2>/dev/null || echo "Already registered"
echo -e "${GREEN}✓ Resource providers registered${NC}"
echo

echo -e "${YELLOW}[2/6] Creating resource group...${NC}"
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output table
echo -e "${GREEN}✓ Resource group created${NC}"
echo

echo -e "${YELLOW}[3/6] Getting user information for RBAC...${NC}"
USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
if [ -z "$USER_OBJECT_ID" ]; then
  echo -e "${RED}Failed to retrieve signed-in user Object ID.${NC}" >&2
  exit 1
fi
echo -e "${GREEN}✓ User Object ID detected${NC}"
echo

echo -e "${YELLOW}[4/6] Deploying infrastructure (this may take 5-10 minutes)...${NC}"
cd "$SCRIPT_DIR/../infrastructure"
deploy_infrastructure
echo

echo -e "${YELLOW}[5/6] Reading deployment outputs...${NC}"
AKS_NAME=$(az deployment group show --resource-group "$RESOURCE_GROUP" --name "$DEPLOYMENT_NAME" --query properties.outputs.aksClusterName.value --output tsv)
ACR_NAME=$(az deployment group show --resource-group "$RESOURCE_GROUP" --name "$DEPLOYMENT_NAME" --query properties.outputs.acrName.value --output tsv)
AGC_SUBNET_ID=$(az deployment group show --resource-group "$RESOURCE_GROUP" --name "$DEPLOYMENT_NAME" --query properties.outputs.agcSubnetId.value --output tsv)
AGC_IDENTITY_PRINCIPAL_ID=$(az deployment group show --resource-group "$RESOURCE_GROUP" --name "$DEPLOYMENT_NAME" --query properties.outputs.agcIdentityPrincipalId.value --output tsv)
NODE_RESOURCE_GROUP_NAME=$(az deployment group show --resource-group "$RESOURCE_GROUP" --name "$DEPLOYMENT_NAME" --query properties.outputs.nodeResourceGroupName.value --output tsv)
RESOURCE_GROUP_ID=$(az group show --name "$RESOURCE_GROUP" --query id --output tsv)
NODE_RESOURCE_GROUP_ID=$(az group show --name "$NODE_RESOURCE_GROUP_NAME" --query id --output tsv)
echo -e "${GREEN}✓ AKS Cluster: ${AKS_NAME}${NC}"
echo -e "${GREEN}✓ ACR: ${ACR_NAME}${NC}"
echo -e "${GREEN}✓ AKS infrastructure resource group: ${NODE_RESOURCE_GROUP_NAME}${NC}"
echo

echo -e "${YELLOW}[6/6] Assigning AGC managed identity permissions...${NC}"
ensure_role_assignment "$AGC_IDENTITY_PRINCIPAL_ID" "ServicePrincipal" "$READER_ROLE_ID" "$RESOURCE_GROUP_ID" "Reader on AKS resource group"
ensure_role_assignment "$AGC_IDENTITY_PRINCIPAL_ID" "ServicePrincipal" "$AGC_CONFIG_MANAGER_ROLE_ID" "$NODE_RESOURCE_GROUP_ID" "AppGw for Containers Configuration Manager on AKS infrastructure resource group"
ensure_role_assignment "$AGC_IDENTITY_PRINCIPAL_ID" "ServicePrincipal" "$NETWORK_CONTRIBUTOR_ROLE_ID" "$AGC_SUBNET_ID" "Network Contributor on AGC delegated subnet"
echo -e "${GREEN}✓ AGC managed identity permissions assigned${NC}"
echo

echo -e "${GREEN}✓ Infrastructure deployment complete${NC}"
echo -e "  AKS Cluster: ${AKS_NAME}"
echo -e "  ACR: ${ACR_NAME}"
echo
