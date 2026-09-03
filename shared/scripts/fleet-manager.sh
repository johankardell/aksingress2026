#!/bin/bash

FLEET_RESOURCE_GROUP="${FLEET_RESOURCE_GROUP:-rg-06-aks-fleet-demo}"
FLEET_NAME="${FLEET_NAME:-aks-ingress-demo-fleet}"
FLEET_EXTENSION_MIN_VERSION="1.8.3"
FLEET_EXTENSION_READY=false

fleet_exists() {
  local resource_group_exists
  if ! resource_group_exists=$(az group exists --name "$FLEET_RESOURCE_GROUP" --output tsv); then
    echo -e "${RED}Failed to check for the AKS Fleet Manager resource group.${NC}" >&2
    return 2
  fi

  if [ "$resource_group_exists" != "true" ]; then
    return 1
  fi

  local fleet_count
  if ! fleet_count=$(az resource list \
    --resource-group "$FLEET_RESOURCE_GROUP" \
    --resource-type "Microsoft.ContainerService/fleets" \
    --query "[?name == '$FLEET_NAME'] | length(@)" \
    --output tsv); then
    echo -e "${RED}Failed to check for AKS Fleet Manager '$FLEET_NAME'.${NC}" >&2
    return 2
  fi

  [ "$fleet_count" = "1" ]
}

ensure_fleet_extension() {
  if [ "$FLEET_EXTENSION_READY" = true ]; then
    return
  fi

  local installed_version
  installed_version=$(az extension show --name fleet --query version --output tsv 2>/dev/null || true)

  if [ -z "$installed_version" ]; then
    echo "Installing Azure CLI fleet extension..."
    if ! az extension add --name fleet --only-show-errors --output none; then
      echo -e "${RED}Failed to install the Azure CLI fleet extension.${NC}" >&2
      return 1
    fi
  elif [ "$(printf '%s\n' "$FLEET_EXTENSION_MIN_VERSION" "$installed_version" | sort -V | head -n 1)" != "$FLEET_EXTENSION_MIN_VERSION" ]; then
    echo "Updating Azure CLI fleet extension from $installed_version..."
    if ! az extension update --name fleet --only-show-errors --output none; then
      echo -e "${RED}Failed to update the Azure CLI fleet extension.${NC}" >&2
      return 1
    fi
  fi

  if ! installed_version=$(az extension show --name fleet --query version --output tsv); then
    echo -e "${RED}Failed to read the Azure CLI fleet extension version.${NC}" >&2
    return 1
  fi
  if [ "$(printf '%s\n' "$FLEET_EXTENSION_MIN_VERSION" "$installed_version" | sort -V | head -n 1)" != "$FLEET_EXTENSION_MIN_VERSION" ]; then
    echo -e "${RED}Azure CLI fleet extension $FLEET_EXTENSION_MIN_VERSION or later is required; found $installed_version.${NC}" >&2
    return 1
  fi

  FLEET_EXTENSION_READY=true
}

ensure_demo_cluster_fleet_membership() {
  local member_name="$1"
  local cluster_id="$2"

  # The Fleet CLI validator currently requires ARM's canonical resourceGroups casing.
  cluster_id="${cluster_id//\/resourcegroups\//\/resourceGroups\/}"

  local fleet_status=0
  fleet_exists || fleet_status=$?
  if [ "$fleet_status" -eq 1 ]; then
    echo "AKS Fleet Manager is not deployed; skipping Fleet membership."
    return
  elif [ "$fleet_status" -ne 0 ]; then
    return "$fleet_status"
  fi

  ensure_fleet_extension || return $?

  local existing_cluster_id
  if ! existing_cluster_id=$(az fleet member list \
    --resource-group "$FLEET_RESOURCE_GROUP" \
    --fleet-name "$FLEET_NAME" \
    --query "[?name == '$member_name'].clusterResourceId | [0]" \
    --output tsv); then
    echo -e "${RED}Failed to list members in AKS Fleet Manager '$FLEET_NAME'.${NC}" >&2
    return 1
  fi

  if [ -n "$existing_cluster_id" ]; then
    if [ "${existing_cluster_id,,}" != "${cluster_id,,}" ]; then
      echo -e "${RED}Fleet member '$member_name' already points to a different cluster: $existing_cluster_id${NC}" >&2
      return 1
    fi

    echo "Fleet member already exists: $member_name"
    return
  fi

  echo "Adding AKS cluster to Fleet Manager: $member_name"
  if ! az fleet member create \
    --resource-group "$FLEET_RESOURCE_GROUP" \
    --fleet-name "$FLEET_NAME" \
    --name "$member_name" \
    --member-cluster-id "$cluster_id" \
    --output none; then
    echo -e "${RED}Failed to add AKS cluster '$member_name' to Fleet Manager.${NC}" >&2
    return 1
  fi
}

remove_demo_resource_group_from_fleet() {
  local demo_resource_group="$1"

  local fleet_status=0
  fleet_exists || fleet_status=$?
  if [ "$fleet_status" -eq 1 ]; then
    echo "AKS Fleet Manager is not deployed; no Fleet membership to remove."
    return
  elif [ "$fleet_status" -ne 0 ]; then
    return "$fleet_status"
  fi

  ensure_fleet_extension || return $?

  local member_rows
  if ! member_rows=$(az fleet member list \
    --resource-group "$FLEET_RESOURCE_GROUP" \
    --fleet-name "$FLEET_NAME" \
    --query "[].[name, clusterResourceId]" \
    --output tsv); then
    echo -e "${RED}Failed to list members in AKS Fleet Manager '$FLEET_NAME'.${NC}" >&2
    return 1
  fi

  local member_name cluster_id
  while IFS=$'\t' read -r member_name cluster_id; do
    if [ -z "$member_name" ] || [ -z "$cluster_id" ]; then
      continue
    fi

    if [[ "${cluster_id,,}" == *"/resourcegroups/${demo_resource_group,,}/providers/microsoft.containerservice/managedclusters/"* ]]; then
      echo "Removing AKS cluster from Fleet Manager: $member_name"
      if ! az fleet member delete \
        --resource-group "$FLEET_RESOURCE_GROUP" \
        --fleet-name "$FLEET_NAME" \
        --name "$member_name" \
        --yes \
        --output none; then
        echo -e "${RED}Failed to remove AKS cluster '$member_name' from Fleet Manager.${NC}" >&2
        return 1
      fi
    fi
  done <<< "$member_rows"
}

reconcile_demo_fleet_members() {
  local demo_resource_groups=(
    "rg-01-nginx-ingress-demo"
    "rg-02-envoy-gateway-demo"
    "rg-03-agc-containers-demo"
    "rg-04-istio-ambient-demo"
    "rg-05-afd-appgw-demo"
  )

  local demo_resource_group cluster_name cluster_id
  for demo_resource_group in "${demo_resource_groups[@]}"; do
    local resource_group_exists
    if ! resource_group_exists=$(az group exists --name "$demo_resource_group" --output tsv); then
      echo -e "${RED}Failed to check demo resource group: $demo_resource_group${NC}" >&2
      return 1
    fi

    if [ "$resource_group_exists" != "true" ]; then
      continue
    fi

    if ! cluster_name=$(az aks list \
      --resource-group "$demo_resource_group" \
      --query "[0].name" \
      --output tsv); then
      echo -e "${RED}Failed to discover AKS clusters in $demo_resource_group.${NC}" >&2
      return 1
    fi

    if [ -z "$cluster_name" ]; then
      continue
    fi

    if ! cluster_id=$(az aks show \
      --resource-group "$demo_resource_group" \
      --name "$cluster_name" \
      --query id \
      --output tsv); then
      echo -e "${RED}Failed to read the AKS resource ID for $cluster_name.${NC}" >&2
      return 1
    fi

    ensure_demo_cluster_fleet_membership "$cluster_name" "$cluster_id" || return $?
  done
}
