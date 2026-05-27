#!/bin/bash

SHARED_ACR_RESOURCE_GROUP="${SHARED_ACR_RESOURCE_GROUP:-rg-aksdemo-shared}"
SHARED_ACR_LOCATION="${SHARED_ACR_LOCATION:-swedencentral}"
SHARED_ACR_SKU="${SHARED_ACR_SKU:-Standard}"

get_shared_acr_name() {
  if [ -n "${SHARED_ACR_NAME:-}" ]; then
    echo "$SHARED_ACR_NAME"
    return
  fi

  local subscription_id suffix
  subscription_id=$(az account show --query id --output tsv)
  suffix=$(printf '%s' "$subscription_id" | tr -cd '[:alnum:]' | tr '[:upper:]' '[:lower:]' | cut -c1-12)

  echo "aksdemo${suffix}acr"
}

ensure_shared_acr() {
  local acr_name
  acr_name=$(get_shared_acr_name)

  echo "Ensuring shared resource group ${SHARED_ACR_RESOURCE_GROUP} exists..." >&2
  az group create \
    --name "$SHARED_ACR_RESOURCE_GROUP" \
    --location "$SHARED_ACR_LOCATION" \
    --output table >&2

  if az acr show --name "$acr_name" --resource-group "$SHARED_ACR_RESOURCE_GROUP" >/dev/null 2>&1; then
    echo "Reusing shared ACR ${acr_name} in ${SHARED_ACR_RESOURCE_GROUP}." >&2
  else
    echo "Creating shared ACR ${acr_name} in ${SHARED_ACR_RESOURCE_GROUP}..." >&2
    if ! az acr create \
      --name "$acr_name" \
      --resource-group "$SHARED_ACR_RESOURCE_GROUP" \
      --location "$SHARED_ACR_LOCATION" \
      --sku "$SHARED_ACR_SKU" \
      --admin-enabled false \
      --output table >&2; then
      if az acr show --name "$acr_name" --resource-group "$SHARED_ACR_RESOURCE_GROUP" >/dev/null 2>&1; then
        echo "Shared ACR ${acr_name} was created by another process; reusing it." >&2
      else
        return 1
      fi
    fi
  fi

  echo "$acr_name"
}

get_shared_acr_login_server() {
  local acr_name="$1"

  az acr show \
    --name "$acr_name" \
    --resource-group "$SHARED_ACR_RESOURCE_GROUP" \
    --query loginServer \
    --output tsv
}

compute_sample_app_image_tag() {
  local sample_app_dir="$1"
  local source_hash

  if ! source_hash=$(cd "$sample_app_dir" && find . -type f \
    ! -path './bin/*' \
    ! -path './obj/*' \
    ! -name '*.md' \
    -print | LC_ALL=C sort | while IFS= read -r file; do sha256sum "$file"; done | sha256sum | awk '{print $1}'); then
    return 1
  fi

  echo "sha-${source_hash}"
}

ensure_sample_app_image() {
  local acr_name="$1"
  local sample_app_dir="$2"
  local image_repository="$3"
  local image_tag

  if ! image_tag=$(compute_sample_app_image_tag "$sample_app_dir"); then
    return 1
  fi
  SAMPLE_APP_IMAGE_TAG="$image_tag"

  echo "Resolved sample app image tag: ${image_repository}:${image_tag}"
  if az acr repository show-tags \
    --name "$acr_name" \
    --repository "$image_repository" \
    --output tsv 2>/dev/null | grep -Fxq "$image_tag"; then
    echo "Image ${image_repository}:${image_tag} already exists in ACR. Skipping build."
    return
  fi

  echo "Image ${image_repository}:${image_tag} not found in ACR. Building with ACR Tasks..."
  cd "$sample_app_dir" || return 1
  az acr build \
    --registry "$acr_name" \
    --image "${image_repository}:${image_tag}" \
    --file Dockerfile \
    . \
    --output table
}
