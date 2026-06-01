# Gateway API with Envoy Demo - Infrastructure

This folder contains Bicep infrastructure-as-code templates for deploying the AKS cluster with Gateway API support and supporting Azure resources. The Azure Container Registry is shared across demos and is created or reused by the deployment script in `rg-aksdemo-shared`.

## Resources Deployed

- **AKS Cluster**: With Workload Identity, OIDC Issuer, Microsoft Entra ID authentication, Azure RBAC, and local accounts disabled
- **Shared Azure Container Registry reference**: Existing registry in `rg-aksdemo-shared` used for the demo application image
- **Shared Azure Monitor workspace and Azure Managed Grafana**: Created or reused in `rg-aksdemo-shared` for managed Prometheus metrics from all demos
- **Log Analytics Workspace**: For Container Insights logs and diagnostics
- **Managed Prometheus collection**: AKS `azureMonitorProfile.metrics` plus a data collection rule that sends metrics to the shared Azure Monitor workspace
- **Managed Identity**: System-assigned identity for AKS
- **RBAC Role Assignment**: User AKS access; AKS `AcrPull` on the shared registry is assigned by `scripts/deploy-infra.sh`

## Key Features

This infrastructure enables modern AKS practices:

- **Gateway API Support**: Ready for Gateway API resources
- **Workload Identity**: Modern authentication mechanism for pods
- **OIDC Issuer**: For workload identity federation
- **Microsoft Entra ID + Azure RBAC**: User access without admin kubeconfigs
- **Azure CNI**: Advanced networking capabilities
- **Azure Monitor Integration**: Comprehensive observability

## Architecture

```
┌─────────────────────────────────────────┐
│         Resource Group                  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │   AKS Cluster                    │  │
│  │   - System Node Pool (2 nodes)   │  │
│  │   - Azure CNI Networking         │  │
│  │   - Workload Identity Enabled    │  │
│  │   - OIDC Issuer Enabled          │  │
│  └──────────────────────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │ Shared ACR (rg-aksdemo-shared)   │  │
│  │   - Standard SKU                 │  │
│  └──────────────────────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │   Log Analytics Workspace        │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## Parameters

Key parameters in `main.bicepparam`:

- `location`: Azure region (default: swedencentral)
- `baseName`: Base name for resources (default: envoy-demo)
- `kubernetesVersion`: AKS version (default: 1.35.4)
- `systemNodeSize`: VM size (default: Standard_B4as_v2)
- `systemNodeCount`: Number of nodes (default: 2)
- `maintenanceDayOfWeek`: AKS auto-upgrade and node OS image maintenance day (default: Sunday)
- `maintenanceStartTime`: AKS maintenance start time in HH:mm in the configured UTC offset (default: 02:00)
- `maintenanceDurationHours`: AKS maintenance window duration in hours (default: 4)
- `maintenanceUtcOffset`: Fixed AKS maintenance window UTC offset for Sweden local expectations (default: +01:00; use +02:00 for Swedish summer time)

The AKS Kubernetes auto-upgrade and managed node OS image schedules use the same weekly nighttime maintenance window.

## Deployment

### Using Azure CLI

```bash
# Create resource group
az group create --name rg-02-envoy-gateway-demo --location swedencentral

# Create or reuse the shared resource group/ACR, then deploy Bicep template.
# The template also creates or reuses shared Grafana and Azure Monitor workspace resources there.
source ../../shared/scripts/acr-image.sh
ACR_NAME=$(ensure_shared_acr)
USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
az deployment group create \
  --resource-group rg-02-envoy-gateway-demo \
  --name envoy-demo-deployment \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --parameters userObjectId="$USER_OBJECT_ID" \
  --parameters sharedAcrName="$ACR_NAME" \
  --parameters sharedAcrResourceGroupName="$SHARED_ACR_RESOURCE_GROUP"
```

### Get Deployment Outputs

```bash
az deployment group show \
  --resource-group rg-02-envoy-gateway-demo \
  --name envoy-demo-deployment \
  --query properties.outputs
```

## Outputs

The deployment provides these outputs:

- `aksClusterName`: Name of the AKS cluster
- `aksClusterId`: Resource ID of the AKS cluster
- `oidcIssuerUrl`: OIDC issuer URL for workload identity
- `acrName`: Name of the shared ACR
- `acrLoginServer`: Login server URL for the shared ACR
- `azureMonitorWorkspaceName`: Name of the shared Azure Monitor workspace
- `azureMonitorWorkspaceId`: Resource ID of the shared Azure Monitor workspace
- `grafanaName`: Name of the shared Azure Managed Grafana instance
- `grafanaEndpoint`: Endpoint URL for the shared Grafana instance
- `resourceGroupName`: Resource group name
- `nodeResourceGroupName`: AKS-managed infrastructure resource group name (`<resource-group>-infra`)

## Modern AKS Features Explained

### Workload Identity
Allows Kubernetes pods to authenticate to Azure services using Azure AD workload identities instead of storing credentials.

### OIDC Issuer
Enables the AKS cluster to issue tokens that can be used for workload identity federation.

### Azure CNI
Provides advanced networking where each pod gets an IP address from the virtual network subnet.

## Cost Estimation

Approximate monthly costs for the Sweden Central demos. Actual Azure pricing is region-dependent and may vary with usage:

- AKS Cluster: ~$70/month (2 x Standard_B4as_v2 nodes)
- Shared Azure Container Registry (Standard): ~$20/month total in `rg-aksdemo-shared`
- Shared Azure Managed Grafana and managed Prometheus ingestion: usage-based in `rg-aksdemo-shared`
- Log Analytics: ~$5/month (minimal ingestion)
- Load Balancer (created later): ~$20/month

**Total**: ~$185/month

💡 Remember to delete resources when not in use to avoid charges.

## Clean Up

```bash
# Delete the resource group (removes all resources)
az group delete --name rg-02-envoy-gateway-demo --yes --no-wait
```

This deletes only the demo resource group. Delete `rg-aksdemo-shared` separately only after all demos are cleaned up and you no longer need the shared ACR, Azure Monitor workspace, or Grafana dashboards.

## Next Steps

After infrastructure deployment:
1. Get AKS credentials: `az aks get-credentials`
2. Build the shared container image in ACR
3. Install Envoy Gateway
4. Deploy Gateway API resources
5. Deploy the application
