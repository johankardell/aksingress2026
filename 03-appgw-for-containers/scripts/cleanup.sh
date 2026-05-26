#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}========================================================${NC}"
echo -e "${YELLOW}  Application Gateway for Containers - Cleanup Script${NC}"
echo -e "${YELLOW}========================================================${NC}"
echo

RESOURCE_GROUP="rg-03-appgw-containers-demo"

# Confirm deletion
echo -e "${RED}WARNING: This will delete the following:${NC}"
echo -e "  - Resource Group: ${RESOURCE_GROUP}"
echo -e "  - AKS Cluster and all resources inside"
echo -e "  - Application Gateway for Containers"
echo -e "  - Azure Container Registry"
echo -e "  - Virtual Network"
echo -e "  - Log Analytics Workspace"
echo -e "  - All associated resources"
echo
read -p "Are you sure you want to continue? (yes/no): " -r
echo

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${GREEN}Cleanup cancelled.${NC}"
    exit 0
fi

echo -e "${YELLOW}[1/2] Deleting Kubernetes resources...${NC}"
# Delete Gateway API resources
kubectl delete httproute appgw-demo-route --ignore-not-found=true
kubectl delete gateway appgw-demo-gateway --ignore-not-found=true
kubectl delete deployment appgw-demo-app --ignore-not-found=true
kubectl delete service appgw-demo-service --ignore-not-found=true

# Delete ApplicationLoadBalancer
kubectl delete applicationloadbalancer -n kube-system alb-controller --ignore-not-found=true

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
echo "Application Gateway for Containers resources may take additional time to clean up."
