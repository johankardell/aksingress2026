# Gateway API with Envoy Demo - Infrastructure

This folder contains Bicep infrastructure-as-code templates for deploying the AKS cluster with Gateway API support and supporting Azure resources.

## Resources Deployed

- **AKS Cluster**: With Workload Identity, OIDC Issuer, Microsoft Entra ID authentication, Azure RBAC, and local accounts disabled
- **Azure Container Registry**: For storing container images
- **Log Analytics Workspace**: For monitoring and diagnostics
- **Managed Identity**: System-assigned identity for AKS
- **RBAC Role Assignment**: ACR Pull permission for AKS

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
│  │   Azure Container Registry       │  │
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

# Deploy Bicep template
az deployment group create \
  --resource-group rg-02-envoy-gateway-demo \
  --name envoy-demo-deployment \
  --template-file main.bicep \
  --parameters main.bicepparam
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
- `acrName`: Name of the ACR
- `acrLoginServer`: Login server URL for ACR
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
- Azure Container Registry (Standard): ~$20/month
- Log Analytics: ~$5/month (minimal ingestion)
- Load Balancer (created later): ~$20/month

**Total**: ~$185/month

💡 Remember to delete resources when not in use to avoid charges.

## Clean Up

```bash
# Delete the resource group (removes all resources)
az group delete --name rg-02-envoy-gateway-demo --yes --no-wait
```

## Next Steps

After infrastructure deployment:
1. Get AKS credentials: `az aks get-credentials`
2. Build and push the container image to ACR
3. Install Envoy Gateway
4. Deploy Gateway API resources
5. Deploy the application
