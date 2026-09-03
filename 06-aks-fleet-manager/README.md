# AKS Fleet Manager Demo

This demo adds a minimal [Azure Kubernetes Fleet Manager](https://learn.microsoft.com/azure/kubernetes-fleet/overview) resource around the five independent AKS ingress demos. It is intentionally hubless and does not change application traffic, ingress, or gateway behavior.

## What it deploys

| Resource | Configuration |
| --- | --- |
| Fleet Manager | `aks-ingress-demo-fleet` |
| Resource group | `rg-06-aks-fleet-demo` |
| Region | `swedencentral` |
| Fleet type | Hubless |
| Identity | System-assigned managed identity |

A hubless Fleet has no hub-cluster compute. It can group the demo clusters and supports Fleet update orchestration, but this repository does not configure update runs or other Fleet features.

## Prerequisites

- Azure CLI 2.82.0 or later
- Permission to create Fleet Manager resources and Fleet memberships
- The Azure CLI `fleet` extension version 1.8.3 or later; the script installs it when needed

## Deploy

```bash
cd 06-aks-fleet-manager
./scripts/deploy.sh
```

The deployment creates the Fleet and discovers AKS clusters in the five known demo resource groups. Existing clusters are joined as members. If another demo is deployed later, its infrastructure script detects the Fleet and joins its AKS cluster automatically.

List current members:

```bash
az fleet member list \
  --resource-group rg-06-aks-fleet-demo \
  --fleet-name aks-ingress-demo-fleet \
  --output table
```

## Cleanup

```bash
./scripts/cleanup.sh
```

Cleanup deletes only `rg-06-aks-fleet-demo`, including the Fleet resource and membership records. It does not delete any member AKS cluster or ingress demo resource group.

Each ingress demo cleanup script removes that cluster's Fleet membership before deleting its own resource group when the Fleet is present.
