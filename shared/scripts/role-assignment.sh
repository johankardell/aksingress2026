#!/bin/bash
set -e

ensure_role_assignment() {
  local principal_id="$1"
  local principal_type="$2"
  local role_id="$3"
  local scope="$4"
  local description="$5"

  if [ -z "$principal_id" ] || [ -z "$scope" ]; then
    echo -e "${RED}Cannot assign $description because principal or scope is empty.${NC}" >&2
    exit 1
  fi

  local existing_count
  existing_count=$(az role assignment list \
    --assignee "$principal_id" \
    --role "$role_id" \
    --scope "$scope" \
    --query "length(@)" \
    --output tsv 2>/dev/null || echo "0")

  if [ "$existing_count" != "0" ]; then
    echo "Role assignment already exists: $description"
    return
  fi

  echo "Creating role assignment: $description"
  for attempt in {1..6}; do
    if az role assignment create \
      --assignee-object-id "$principal_id" \
      --assignee-principal-type "$principal_type" \
      --role "$role_id" \
      --scope "$scope" \
      --output none; then
      return
    fi

    if [ "$attempt" -eq 6 ]; then
      echo -e "${RED}Failed to create role assignment after multiple attempts: $description${NC}" >&2
      exit 1
    fi

    echo "Role assignment failed, waiting for identity propagation before retry..."
    sleep 20
  done
}
