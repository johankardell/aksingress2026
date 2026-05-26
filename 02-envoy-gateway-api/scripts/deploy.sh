#!/bin/bash
set -e
set -o pipefail

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  Gateway API with Envoy - Deployment Orchestrator${NC}"
echo -e "${GREEN}================================================${NC}"
echo

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

"$SCRIPT_DIR/deploy-infra.sh"
"$SCRIPT_DIR/build-image.sh"
"$SCRIPT_DIR/configure-kubernetes.sh"
