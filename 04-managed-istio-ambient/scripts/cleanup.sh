#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}================================================${NC}"
echo -e "${YELLOW}  Managed Istio Ambient - Cleanup Script${NC}"
echo -e "${YELLOW}================================================${NC}"
echo

SHARED_ACR_RESOURCE_GROUP="rg-aksdemo-shared"
RESOURCE_GROUP="rg-04-istio-ambient-demo"
APP_NAMESPACE="mesh-demo"

echo -e "${RED}WARNING: This will delete the following:${NC}"
echo -e "  - Resource Group: ${RESOURCE_GROUP}"
echo -e "  - AKS cluster, Azure Kubernetes Application Network resource, and Log Analytics workspace"
echo -e "  - Demo Kubernetes resources if the cluster is reachable"
echo -e "${YELLOW}Note: Shared ACR, Azure Monitor workspace, and Grafana are not deleted by this script.${NC}"
echo
read -p "Are you sure you want to continue? (yes/no): " -r
echo

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
  echo -e "${GREEN}Cleanup cancelled.${NC}"
  exit 0
fi

echo -e "${YELLOW}[1/2] Deleting Kubernetes resources...${NC}"
kubectl delete httproute frontend-route -n "$APP_NAMESPACE" --ignore-not-found=true 2>/dev/null || true
kubectl delete gateway mesh-demo-gateway mesh-demo-waypoint -n "$APP_NAMESPACE" --ignore-not-found=true 2>/dev/null || true
kubectl delete telemetry mesh-demo-default -n "$APP_NAMESPACE" --ignore-not-found=true 2>/dev/null || true
kubectl delete namespace "$APP_NAMESPACE" --ignore-not-found=true 2>/dev/null || true
helm uninstall kiali-server -n kiali-system 2>/dev/null || true
helm uninstall prometheus -n monitoring 2>/dev/null || true
kubectl delete namespace kiali-system monitoring --ignore-not-found=true 2>/dev/null || true
echo -e "${GREEN}✓ Kubernetes cleanup requested${NC}"
echo

echo -e "${YELLOW}[2/2] Deleting Azure resources...${NC}"
az group delete \
  --name "$RESOURCE_GROUP" \
  --yes \
  --no-wait

echo -e "${GREEN}✓ Resource group deletion initiated${NC}"
echo
echo "Shared ACR remains in $SHARED_ACR_RESOURCE_GROUP for other demos."
echo "To delete shared resources after all demos are removed: az group delete --name $SHARED_ACR_RESOURCE_GROUP --yes --no-wait"
echo
