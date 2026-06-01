#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}================================================${NC}"
echo -e "${YELLOW}  Gateway API with Envoy - Cleanup Script${NC}"
echo -e "${YELLOW}================================================${NC}"
echo

SHARED_ACR_RESOURCE_GROUP="rg-aksdemo-shared"
RESOURCE_GROUP="rg-02-envoy-gateway-demo"
APP_NAMESPACE="demo"

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

echo -e "${YELLOW}[1/2] Deleting Kubernetes resources...${NC}"
# Delete Gateway API resources
kubectl delete httproute envoy-demo-route -n "$APP_NAMESPACE" --ignore-not-found=true
kubectl delete gateway envoy-demo-gateway -n "$APP_NAMESPACE" --ignore-not-found=true
kubectl delete deployment envoy-demo-app -n "$APP_NAMESPACE" --ignore-not-found=true
kubectl delete service envoy-demo-service -n "$APP_NAMESPACE" --ignore-not-found=true
kubectl delete namespace "$APP_NAMESPACE" --ignore-not-found=true

# Delete Envoy Gateway
helm uninstall envoy-gateway -n envoy-gateway-system 2>/dev/null || echo "Helm release not found"
kubectl delete namespace envoy-gateway-system --ignore-not-found=true

echo -e "${GREEN}✓ Kubernetes resources deleted${NC}"
echo

echo -e "${YELLOW}[2/2] Deleting Azure resources...${NC}"
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
