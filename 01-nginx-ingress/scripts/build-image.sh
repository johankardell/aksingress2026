#!/bin/bash
set -e
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  NGINX Ingress Demo - Image Build${NC}"
echo -e "${GREEN}================================================${NC}"
echo

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
IMAGE_REPOSITORY="aks-ingress-demo"
source "$REPO_ROOT/shared/scripts/acr-image.sh"

command -v az >/dev/null 2>&1 || { echo -e "${RED}Azure CLI is required but not installed.${NC}" >&2; exit 1; }

echo -e "${YELLOW}[1/2] Ensuring shared Azure Container Registry...${NC}"
ACR_NAME=$(ensure_shared_acr)
ACR_LOGIN_SERVER=$(get_shared_acr_login_server "$ACR_NAME")
echo -e "${GREEN}✓ Shared ACR: ${ACR_NAME} (${SHARED_ACR_RESOURCE_GROUP})${NC}"
echo

echo -e "${YELLOW}[2/2] Ensuring container image exists in shared ACR...${NC}"
ensure_sample_app_image "$ACR_NAME" "$REPO_ROOT/shared/sample-app" "$IMAGE_REPOSITORY"
echo -e "${GREEN}✓ Container image is available in shared ACR${NC}"
echo -e "  Image: ${ACR_LOGIN_SERVER}/${IMAGE_REPOSITORY}:${SAMPLE_APP_IMAGE_TAG}"
echo
