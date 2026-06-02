#!/bin/bash
set -e
set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  Managed Istio Ambient - Infrastructure Deployment${NC}"
echo -e "${GREEN}================================================${NC}"
echo

RESOURCE_GROUP="rg-04-istio-ambient-demo"
LOCATION="northeurope"
ACR_PULL_ROLE_ID="7f951dda-4ed3-4680-a7ca-43fe172d538d"
DEPLOYMENT_NAME="istio-ambient-demo-deployment"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
source "$REPO_ROOT/shared/scripts/acr-image.sh"
source "$REPO_ROOT/shared/scripts/role-assignment.sh"

command -v az >/dev/null 2>&1 || { echo -e "${RED}Azure CLI is required but not installed.${NC}" >&2; exit 1; }

register_feature_best_effort() {
  local namespace="$1"
  local feature="$2"

  echo "Registering preview feature ${namespace}/${feature} if available..."
  az feature register --namespace "$namespace" --name "$feature" --output none 2>/dev/null || \
    echo -e "${YELLOW}⚠ Preview feature ${namespace}/${feature} was not registered automatically. If deployment fails, register the Application Network preview feature approved for your subscription.${NC}"
}

ensure_appnet_extension() {
  if az appnet --help >/dev/null 2>&1; then
    return
  fi

  echo "Installing/updating Azure CLI appnet extension..."
  az extension add --name appnet --upgrade --allow-preview true --output none 2>/dev/null || \
    echo -e "${YELLOW}⚠ Could not install the appnet extension automatically. Install it manually if az appnet commands are unavailable.${NC}"
}

echo -e "${YELLOW}[1/7] Registering Azure resource providers and preview features...${NC}"
az provider register --namespace Microsoft.ContainerService --wait 2>/dev/null || echo "Microsoft.ContainerService already registered or registration in progress"
az provider register --namespace Microsoft.OperationsManagement --wait 2>/dev/null || echo "Microsoft.OperationsManagement already registered or registration in progress"
az provider register --namespace Microsoft.ContainerRegistry --wait 2>/dev/null || echo "Microsoft.ContainerRegistry already registered or registration in progress"
az provider register --namespace Microsoft.Monitor --wait 2>/dev/null || echo "Microsoft.Monitor already registered or registration in progress"
az provider register --namespace Microsoft.Insights --wait 2>/dev/null || echo "Microsoft.Insights already registered or registration in progress"
az provider register --namespace Microsoft.Dashboard --wait 2>/dev/null || echo "Microsoft.Dashboard already registered or registration in progress"
az provider register --namespace Microsoft.AppNet --wait 2>/dev/null || echo "Microsoft.AppNet already registered or registration in progress"
register_feature_best_effort Microsoft.ContainerService AKS-AzureAppNetworkPreview
register_feature_best_effort Microsoft.ContainerService EnableGatewayAPI
ensure_appnet_extension
echo -e "${GREEN}✓ Provider registration requested${NC}"
echo

echo -e "${YELLOW}[2/7] Checking preview regional support...${NC}"
az appnet list-versions --location "$LOCATION" -o table 2>/dev/null || echo -e "${YELLOW}⚠ az appnet list-versions did not return data. Confirm Application Network preview availability for ${LOCATION}.${NC}"
az aks get-versions --location "$LOCATION" --output table
az vm list-skus --location "$LOCATION" --size Standard_B4as_v2 --all --output table | head -20
echo -e "${GREEN}✓ Regional checks completed${NC}"
echo

echo -e "${YELLOW}[3/7] Creating resource group...${NC}"
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table
echo -e "${GREEN}✓ Resource group created${NC}"
echo

echo -e "${YELLOW}[4/7] Ensuring shared resource group and Azure Container Registry...${NC}"
ACR_NAME=$(ensure_shared_acr)
echo -e "${GREEN}✓ Shared ACR: ${ACR_NAME} (${SHARED_ACR_RESOURCE_GROUP})${NC}"
echo

echo -e "${YELLOW}[5/7] Getting user information for RBAC...${NC}"
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
  assignment_ids=$(az role assignment list --assignee "$assignee" --role "$role" --scope "$scope" --query "[].id" --output tsv 2>/dev/null || true)

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
  acr_name=$(get_shared_acr_name)

  if [ -n "$aks_name" ]; then
    aks_id=$(az aks show --resource-group "$RESOURCE_GROUP" --name "$aks_name" --query id --output tsv 2>/dev/null || true)
    kubelet_object_id=$(az aks show --resource-group "$RESOURCE_GROUP" --name "$aks_name" --query identityProfile.kubeletidentity.objectId --output tsv 2>/dev/null || true)
  fi

  if [ -n "$acr_name" ]; then
    acr_id=$(az acr show --resource-group "$SHARED_ACR_RESOURCE_GROUP" --name "$acr_name" --query id --output tsv 2>/dev/null || true)
  fi

  delete_role_assignments_by_role "AcrPull" "$acr_id"
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
    --parameters sharedAcrName="$ACR_NAME" \
    --parameters sharedAcrResourceGroupName="$SHARED_ACR_RESOURCE_GROUP" \
    --output table 2>&1 | tee "$output_file"; then
    rm -f "$output_file"
    return
  fi

  if grep -Eq "RoleAssignmentExists|RoleAssignmentUpdateNotPermitted" "$output_file"; then
    cleanup_conflicting_role_assignments
    rm -f "$output_file"
    az deployment group create \
      --resource-group "$RESOURCE_GROUP" \
      --name "$DEPLOYMENT_NAME" \
      --template-file main.bicep \
      --parameters main.bicepparam \
      --parameters userObjectId="$USER_OBJECT_ID" \
      --parameters sharedAcrName="$ACR_NAME" \
      --parameters sharedAcrResourceGroupName="$SHARED_ACR_RESOURCE_GROUP" \
      --output table
  else
    rm -f "$output_file"
    return 1
  fi
}

echo -e "${YELLOW}[6/7] Deploying infrastructure (this may take 10-20 minutes)...${NC}"
cd "$SCRIPT_DIR/../infrastructure"
deploy_infrastructure

echo -e "${YELLOW}[7/7] Reading deployment outputs and assigning ACR pull...${NC}"
AKS_NAME=$(az deployment group show --resource-group "$RESOURCE_GROUP" --name "$DEPLOYMENT_NAME" --query properties.outputs.aksClusterName.value --output tsv)
ACR_NAME=$(az deployment group show --resource-group "$RESOURCE_GROUP" --name "$DEPLOYMENT_NAME" --query properties.outputs.acrName.value --output tsv)
APPNET_NAME=$(az deployment group show --resource-group "$RESOURCE_GROUP" --name "$DEPLOYMENT_NAME" --query properties.outputs.appNetName.value --output tsv)
AZURE_MONITOR_WORKSPACE_NAME=$(az deployment group show --resource-group "$RESOURCE_GROUP" --name "$DEPLOYMENT_NAME" --query properties.outputs.azureMonitorWorkspaceName.value --output tsv)
GRAFANA_NAME=$(az deployment group show --resource-group "$RESOURCE_GROUP" --name "$DEPLOYMENT_NAME" --query properties.outputs.grafanaName.value --output tsv)
GRAFANA_ENDPOINT=$(az deployment group show --resource-group "$RESOURCE_GROUP" --name "$DEPLOYMENT_NAME" --query properties.outputs.grafanaEndpoint.value --output tsv)
KUBELET_OBJECT_ID=$(az aks show --resource-group "$RESOURCE_GROUP" --name "$AKS_NAME" --query identityProfile.kubeletidentity.objectId --output tsv)
ACR_ID=$(az acr show --resource-group "$SHARED_ACR_RESOURCE_GROUP" --name "$ACR_NAME" --query id --output tsv)

ensure_role_assignment "$KUBELET_OBJECT_ID" "ServicePrincipal" "$ACR_PULL_ROLE_ID" "$ACR_ID" "AcrPull on shared ACR"

echo -e "${GREEN}✓ Infrastructure deployed${NC}"
echo -e "  AKS Cluster: ${AKS_NAME}"
echo -e "  Application Network: ${APPNET_NAME}"
echo -e "  Shared ACR: ${ACR_NAME} (${SHARED_ACR_RESOURCE_GROUP})"
echo -e "  Shared Azure Monitor workspace: ${AZURE_MONITOR_WORKSPACE_NAME} (${SHARED_ACR_RESOURCE_GROUP})"
echo -e "  Shared Grafana: ${GRAFANA_NAME} (${GRAFANA_ENDPOINT})"
echo
