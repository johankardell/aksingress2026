# NGINX Ingress Demo - Infrastructure

This folder contains Bicep infrastructure-as-code templates for deploying the AKS cluster and supporting Azure resources for the NGINX Ingress demo.

## Resources Deployed

- **AKS Cluster**: Standard configuration with Azure CNI networking
- **Azure Container Registry**: For storing the demo application container image
- **Log Analytics Workspace**: For monitoring and diagnostics
- **Managed Identity**: System-assigned identity for AKS
- **RBAC Role Assignment**: ACR Pull permission for AKS

## Architecture

```
┌─────────────────────────────────────────┐
│         Resource Group                  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │   AKS Cluster                    │  │
│  │   - System Node Pool (2 nodes)   │  │
│  │   - Azure CNI Networking         │  │
│  │   - Managed Identity             │  │
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
- `baseName`: Base name for resources (default: nginx-demo)
- `kubernetesVersion`: AKS version (default: 1.34.7)
- `systemNodeSize`: VM size (default: Standard_B4as_v2)
- `systemNodeCount`: Number of nodes (default: 2)

## Deployment

### Using Azure CLI

```bash
# Create resource group
az group create --name rg-01-nginx-ingress-demo --location swedencentral

# Deploy Bicep template
az deployment group create \
  --resource-group rg-01-nginx-ingress-demo \
  --template-file main.bicep \
  --parameters main.bicepparam
```

### Get Deployment Outputs

```bash
az deployment group show \
  --resource-group rg-01-nginx-ingress-demo \
  --name main \
  --query properties.outputs
```

## Outputs

The deployment provides these outputs:

- `aksClusterName`: Name of the AKS cluster
- `aksClusterId`: Resource ID of the AKS cluster
- `acrName`: Name of the ACR
- `acrLoginServer`: Login server URL for ACR
- `resourceGroupName`: Resource group name
- `nodeResourceGroupName`: Node resource group name

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
az group delete --name rg-01-nginx-ingress-demo --yes --no-wait
```

## Next Steps

After infrastructure deployment:
1. Get AKS credentials: `az aks get-credentials`
2. Build and push the container image to ACR
3. Install NGINX Ingress Controller
4. Deploy the application with Kubernetes manifests
