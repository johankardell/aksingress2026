#!/bin/bash

compute_sample_app_image_tag() {
  local sample_app_dir="$1"
  local source_hash

  source_hash=$(cd "$sample_app_dir" && find . -type f \
    ! -path './bin/*' \
    ! -path './obj/*' \
    ! -name '*.md' \
    -print | LC_ALL=C sort | while IFS= read -r file; do sha256sum "$file"; done | sha256sum | awk '{print $1}')

  echo "sha-${source_hash}"
}

ensure_sample_app_image() {
  local acr_name="$1"
  local sample_app_dir="$2"
  local image_repository="$3"
  local image_tag

  image_tag=$(compute_sample_app_image_tag "$sample_app_dir")
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
  cd "$sample_app_dir"
  az acr build \
    --registry "$acr_name" \
    --image "${image_repository}:${image_tag}" \
    --file Dockerfile \
    . \
    --output table
}
