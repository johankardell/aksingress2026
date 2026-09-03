#!/bin/bash
set -e
set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}================================================${NC}"
echo -e "${YELLOW}  AKS Fleet Manager Demo - Cleanup${NC}"
echo -e "${YELLOW}================================================${NC}"
echo

RESOURCE_GROUP="rg-06-aks-fleet-demo"

command -v az >/dev/null 2>&1 || { echo -e "${RED}Azure CLI is required but not installed.${NC}" >&2; exit 1; }

echo -e "${RED}WARNING: This deletes the Fleet Manager resource group and Fleet memberships.${NC}"
echo -e "${YELLOW}Member AKS clusters and their demo resource groups are not deleted.${NC}"
echo
read -p "Are you sure you want to continue? (yes/no): " -r
echo

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
  echo -e "${GREEN}Cleanup cancelled.${NC}"
  exit 0
fi

if ! RESOURCE_GROUP_EXISTS=$(az group exists --name "$RESOURCE_GROUP" --output tsv); then
  echo -e "${RED}Failed to check whether resource group $RESOURCE_GROUP exists.${NC}" >&2
  exit 1
fi

if [ "$RESOURCE_GROUP_EXISTS" != "true" ]; then
  echo "Resource group $RESOURCE_GROUP does not exist."
  exit 0
fi

az group delete \
  --name "$RESOURCE_GROUP" \
  --yes \
  --no-wait

echo -e "${GREEN}✓ Fleet Manager resource group deletion initiated${NC}"
echo "Member AKS clusters remain deployed."
