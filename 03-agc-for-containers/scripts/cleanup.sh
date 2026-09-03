#!/bin/bash
set -e
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}========================================================${NC}"
echo -e "${YELLOW}  AGC - Cleanup Script${NC}"
echo -e "${YELLOW}========================================================${NC}"
echo

SHARED_ACR_RESOURCE_GROUP="rg-aksdemo-shared"
RESOURCE_GROUP="rg-03-agc-containers-demo"
APP_NAMESPACE="demo"
ALB_CONTROLLER_NAMESPACE="azure-alb-system"
ALB_RESOURCE_NAMESPACE="alb-infra"
ALB_RESOURCE_NAME="alb"

command -v az >/dev/null 2>&1 || { echo -e "${RED}Azure CLI is required but not installed.${NC}" >&2; exit 1; }

purge_log_analytics_workspaces() {
  local workspace_names
  workspace_names=$(az monitor log-analytics workspace list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[].name" \
    --output tsv 2>/dev/null || true)

  if [ -z "$workspace_names" ]; then
    echo "No Log Analytics workspaces found in $RESOURCE_GROUP"
    return
  fi

  echo "$workspace_names" | while IFS= read -r workspace_name; do
    if [ -n "$workspace_name" ]; then
      echo "Permanently deleting Log Analytics workspace: $workspace_name"
      az monitor log-analytics workspace delete \
        --resource-group "$RESOURCE_GROUP" \
        --workspace-name "$workspace_name" \
        --force true \
        --yes \
        --output none
    fi
  done
}

# Confirm deletion
echo -e "${RED}WARNING: This will delete the following:${NC}"
echo -e "  - Resource Group: ${RESOURCE_GROUP}"
echo -e "  - AKS Cluster and all resources inside"
echo -e "  - Application Gateway for Containers"
echo -e "  - Virtual Network"
echo -e "  - Log Analytics Workspace"
echo -e "  - All associated resources"
echo -e "${YELLOW}Note: Shared ACR, Azure Monitor workspace, and Grafana are not deleted by this script.${NC}"
echo
read -p "Are you sure you want to continue? (yes/no): " -r
echo

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${GREEN}Cleanup cancelled.${NC}"
    exit 0
fi

echo -e "${YELLOW}[1/3] Deleting Kubernetes resources...${NC}"
if [ "$(az group exists --name "$RESOURCE_GROUP")" != "true" ]; then
  echo -e "${GREEN}Resource group ${RESOURCE_GROUP} no longer exists; nothing to clean up.${NC}"
  exit 0
fi

AKS_NAME=$(az aks list --resource-group "$RESOURCE_GROUP" --query "[0].name" --output tsv)
if [ -n "$AKS_NAME" ]; then
  command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}kubectl is required but not installed.${NC}" >&2; exit 1; }
  command -v helm >/dev/null 2>&1 || { echo -e "${RED}Helm is required but not installed.${NC}" >&2; exit 1; }
  az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_NAME" --overwrite-existing --output none

  # Namespace deletion removes the app and its Gateway API resources together.
  kubectl delete namespace "$APP_NAMESPACE" --ignore-not-found=true

  # Wait for the controller finalizer to remove the Azure data plane before uninstalling it.
  if kubectl get crd applicationloadbalancer.alb.networking.azure.io >/dev/null 2>&1; then
    kubectl delete applicationloadbalancer "$ALB_RESOURCE_NAME" \
      -n "$ALB_RESOURCE_NAMESPACE" \
      --ignore-not-found=true \
      --timeout=10m
  fi
  if helm status alb-controller -n "$ALB_CONTROLLER_NAMESPACE" >/dev/null 2>&1; then
    helm uninstall alb-controller -n "$ALB_CONTROLLER_NAMESPACE"
  else
    echo "ALB Controller Helm release not found"
  fi
  kubectl delete namespace "$ALB_CONTROLLER_NAMESPACE" --ignore-not-found=true
  kubectl delete namespace "$ALB_RESOURCE_NAMESPACE" --ignore-not-found=true
else
  echo "AKS cluster not found; skipping Kubernetes resource cleanup."
fi

echo -e "${GREEN}✓ Kubernetes resources deleted${NC}"
echo

echo -e "${YELLOW}[2/3] Permanently deleting Log Analytics workspaces...${NC}"
purge_log_analytics_workspaces
echo -e "${GREEN}✓ Log Analytics workspace purge complete${NC}"
echo

echo -e "${YELLOW}[3/3] Deleting Azure resources...${NC}"
az group delete \
  --name $RESOURCE_GROUP \
  --yes \
  --no-wait

echo -e "${GREEN}✓ Resource group deletion initiated${NC}"
echo
echo -e "${GREEN}Cleanup complete!${NC}"
echo
echo "Note: Azure resource deletion is running in the background."
echo "To check status: az group show --name $RESOURCE_GROUP"
echo
echo "The resource group will be fully deleted in 5-10 minutes."
echo "Shared ACR remains in $SHARED_ACR_RESOURCE_GROUP for other demos."
echo "To delete the shared ACR after all demos are removed: az group delete --name $SHARED_ACR_RESOURCE_GROUP --yes --no-wait"
echo "AGC resources may take additional time to clean up."
