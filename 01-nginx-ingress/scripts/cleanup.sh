#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}================================================${NC}"
echo -e "${YELLOW}  NGINX Ingress Demo - Cleanup Script${NC}"
echo -e "${YELLOW}================================================${NC}"
echo

SHARED_ACR_RESOURCE_GROUP="rg-aksdemo-shared"
RESOURCE_GROUP="rg-01-nginx-ingress-demo"
APP_NAMESPACE="demo"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
source "$REPO_ROOT/shared/scripts/fleet-manager.sh"

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
# Delete ingress first to release public IP
kubectl delete ingress nginx-demo-ingress -n "$APP_NAMESPACE" --ignore-not-found=true
kubectl delete deployment nginx-demo-app -n "$APP_NAMESPACE" --ignore-not-found=true
kubectl delete service nginx-demo-service -n "$APP_NAMESPACE" --ignore-not-found=true
kubectl delete namespace "$APP_NAMESPACE" --ignore-not-found=true

# Delete NGINX Ingress Controller
helm uninstall ingress-nginx -n ingress-nginx 2>/dev/null || echo "Helm release not found"
kubectl delete namespace ingress-nginx --ignore-not-found=true

echo -e "${GREEN}✓ Kubernetes resources deleted${NC}"
echo

echo -e "${YELLOW}[2/3] Permanently deleting Log Analytics workspaces...${NC}"
purge_log_analytics_workspaces
echo -e "${GREEN}✓ Log Analytics workspace purge complete${NC}"
echo

echo -e "${YELLOW}[3/3] Deleting Azure resources...${NC}"
if ! remove_demo_resource_group_from_fleet "$RESOURCE_GROUP"; then
  echo -e "${RED}Failed to remove the AKS cluster from Fleet Manager.${NC}" >&2
  exit 1
fi
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
