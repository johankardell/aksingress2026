#!/bin/bash
set -e
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  NGINX Ingress Demo - Infrastructure Deployment${NC}"
echo -e "${GREEN}================================================${NC}"
echo

RESOURCE_GROUP="rg-01-nginx-ingress-demo"
LOCATION="swedencentral"
DEPLOYMENT_NAME="nginx-demo-deployment"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

command -v az >/dev/null 2>&1 || { echo -e "${RED}Azure CLI is required but not installed.${NC}" >&2; exit 1; }

echo -e "${YELLOW}[1/4] Registering Azure resource providers...${NC}"
echo "Registering Microsoft.ContainerService..."
az provider register --namespace Microsoft.ContainerService --wait 2>/dev/null || echo "Already registered"
echo "Registering Microsoft.OperationsManagement..."
az provider register --namespace Microsoft.OperationsManagement --wait 2>/dev/null || echo "Already registered"
echo "Registering Microsoft.ContainerRegistry..."
az provider register --namespace Microsoft.ContainerRegistry --wait 2>/dev/null || echo "Already registered"
echo -e "${GREEN}✓ Resource providers registered${NC}"
echo

echo -e "${YELLOW}[2/4] Creating resource group...${NC}"
az group create   --name $RESOURCE_GROUP   --location $LOCATION   --output table
echo -e "${GREEN}✓ Resource group created${NC}"
echo

echo -e "${YELLOW}[3/4] Getting user information for RBAC...${NC}"
USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
if [ -z "$USER_OBJECT_ID" ]; then
  echo -e "${RED}Failed to retrieve signed-in user Object ID.${NC}" >&2
  exit 1
fi
echo -e "${GREEN}✓ User Object ID: ${USER_OBJECT_ID}${NC}"
echo

delete_role_assignments() {
  local assignee="$1"
  local role="$2"
  local scope="$3"

  if [ -z "$assignee" ] || [ -z "$scope" ]; then
    return
  fi

  local assignment_ids
  assignment_ids=$(az role assignment list     --assignee "$assignee"     --role "$role"     --scope "$scope"     --query "[].id"     --output tsv 2>/dev/null || true)

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

delete_role_assignments_by_role() {
  local role="$1"
  local scope="$2"

  if [ -z "$scope" ]; then
    return
  fi

  local assignment_ids
  assignment_ids=$(az role assignment list --role "$role" --scope "$scope" --query "[].id" --output tsv 2>/dev/null || true)

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
  echo -e "${YELLOW}Conflicting role assignment exists. Cleaning known demo role assignments and retrying...${NC}"

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

  delete_role_assignments_by_role "AcrPull" "$acr_id"
  delete_role_assignments "$USER_OBJECT_ID" "Azure Kubernetes Service Cluster User Role" "$aks_id"
  delete_role_assignments "$USER_OBJECT_ID" "Azure Kubernetes Service RBAC Cluster Admin" "$aks_id"
}

deploy_infrastructure() {
  local output_file
  output_file=$(mktemp)

  if az deployment group create     --resource-group $RESOURCE_GROUP     --name $DEPLOYMENT_NAME     --template-file main.bicep     --parameters main.bicepparam     --parameters userObjectId="$USER_OBJECT_ID"     --output table 2>&1 | tee "$output_file"; then
    rm -f "$output_file"
    return
  fi

  if grep -Eq "RoleAssignmentExists|RoleAssignmentUpdateNotPermitted" "$output_file"; then
    cleanup_conflicting_role_assignments
    rm -f "$output_file"
    az deployment group create       --resource-group $RESOURCE_GROUP       --name $DEPLOYMENT_NAME       --template-file main.bicep       --parameters main.bicepparam       --parameters userObjectId="$USER_OBJECT_ID"       --output table
  else
    rm -f "$output_file"
    return 1
  fi
}

echo -e "${YELLOW}[4/4] Deploying infrastructure (this may take 5-10 minutes)...${NC}"
cd "$SCRIPT_DIR/../infrastructure"
deploy_infrastructure

AKS_NAME=$(az deployment group show   --resource-group $RESOURCE_GROUP   --name $DEPLOYMENT_NAME   --query properties.outputs.aksClusterName.value   --output tsv)

ACR_NAME=$(az deployment group show   --resource-group $RESOURCE_GROUP   --name $DEPLOYMENT_NAME   --query properties.outputs.acrName.value   --output tsv)

echo -e "${GREEN}✓ Infrastructure deployed${NC}"
echo -e "  AKS Cluster: ${AKS_NAME}"
echo -e "  ACR: ${ACR_NAME}"
echo
