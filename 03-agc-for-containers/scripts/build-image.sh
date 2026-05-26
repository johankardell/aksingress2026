#!/bin/bash
set -e
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  AGC - Image Build${NC}"
echo -e "${GREEN}================================================${NC}"
echo

RESOURCE_GROUP="rg-03-agc-containers-demo"
DEPLOYMENT_NAME="agc-demo-deployment"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
IMAGE_REPOSITORY="aks-ingress-demo"
source "$REPO_ROOT/shared/scripts/acr-image.sh"

command -v az >/dev/null 2>&1 || { echo -e "${RED}Azure CLI is required but not installed.${NC}" >&2; exit 1; }

echo -e "${YELLOW}[1/2] Reading infrastructure outputs...${NC}"
ACR_NAME=$(az deployment group show   --resource-group $RESOURCE_GROUP   --name $DEPLOYMENT_NAME   --query properties.outputs.acrName.value   --output tsv)
echo -e "${GREEN}✓ ACR: ${ACR_NAME}${NC}"
echo

echo -e "${YELLOW}[2/2] Ensuring container image exists in ACR...${NC}"
ensure_sample_app_image "$ACR_NAME" "$REPO_ROOT/shared/sample-app" "$IMAGE_REPOSITORY"
echo -e "${GREEN}✓ Container image is available in ACR${NC}"
echo -e "  Image: ${IMAGE_REPOSITORY}:${SAMPLE_APP_IMAGE_TAG}"
echo
