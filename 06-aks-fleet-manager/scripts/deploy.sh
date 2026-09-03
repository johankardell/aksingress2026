#!/bin/bash
set -e
set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  AKS Fleet Manager Demo - Deployment${NC}"
echo -e "${GREEN}================================================${NC}"
echo

RESOURCE_GROUP="rg-06-aks-fleet-demo"
LOCATION="swedencentral"
DEPLOYMENT_NAME="aks-fleet-manager-demo-deployment"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
source "$REPO_ROOT/shared/scripts/fleet-manager.sh"

command -v az >/dev/null 2>&1 || { echo -e "${RED}Azure CLI is required but not installed.${NC}" >&2; exit 1; }

echo -e "${YELLOW}[1/4] Registering Microsoft.ContainerService...${NC}"
az provider register --namespace Microsoft.ContainerService --wait --output none
echo -e "${GREEN}✓ Resource provider registered${NC}"
echo

echo -e "${YELLOW}[2/4] Creating resource group...${NC}"
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --tags Environment=demo Demo=AKS-Fleet-Manager ManagedBy=Bash \
  --output table
echo -e "${GREEN}✓ Resource group created${NC}"
echo

echo -e "${YELLOW}[3/4] Deploying hubless Fleet Manager...${NC}"
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DEPLOYMENT_NAME" \
  --template-file "$SCRIPT_DIR/../infrastructure/main.bicep" \
  --parameters "$SCRIPT_DIR/../infrastructure/main.bicepparam" \
  --output table

DEPLOYED_FLEET_NAME=$(az deployment group show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DEPLOYMENT_NAME" \
  --query properties.outputs.fleetName.value \
  --output tsv)
echo -e "${GREEN}✓ Fleet Manager deployed: ${DEPLOYED_FLEET_NAME}${NC}"
echo

echo -e "${YELLOW}[4/4] Reconciling existing demo AKS clusters...${NC}"
reconcile_demo_fleet_members
echo -e "${GREEN}✓ Existing demo clusters reconciled${NC}"
echo

echo -e "${GREEN}Fleet Manager deployment complete!${NC}"
echo "Resource group: $RESOURCE_GROUP"
echo "Fleet Manager: $DEPLOYED_FLEET_NAME"
echo
az fleet member list \
  --resource-group "$RESOURCE_GROUP" \
  --fleet-name "$DEPLOYED_FLEET_NAME" \
  --query "[].{Member:name,Cluster:clusterResourceId}" \
  --output table
