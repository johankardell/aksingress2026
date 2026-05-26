# Application Gateway for Containers Demo - Infrastructure

This folder contains Bicep infrastructure-as-code templates for deploying AKS with Application Gateway for Containers and supporting Azure resources.

## Resources Deployed

- **Virtual Network**: With dedicated subnets for AKS and Application Gateway for Containers
- **AKS Cluster**: With Application Gateway for Containers (Web App Routing), Microsoft Entra ID authentication, Azure RBAC, and local accounts disabled
- **Azure Container Registry**: For storing container images
- **Log Analytics Workspace**: For monitoring and diagnostics
- **Managed Identities**: System-assigned for AKS, user-assigned for Application Gateway for Containers
- **RBAC Role Assignments**: ACR Pull, Network Contributor

## Key Features

This infrastructure showcases Azure-native ingress capabilities:

- **Application Gateway for Containers**: Azure-managed application delivery controller
- **Web App Routing**: AKS add-on for simplified ingress configuration
- **Virtual Network Integration**: Dedicated subnet delegation for Application Gateway
- **Workload Identity**: Modern authentication for Azure services
- **Microsoft Entra ID + Azure RBAC**: User access without admin kubeconfigs
- **Azure Monitor Integration**: Native observability

## Architecture

```
┌─────────────────────────────────────────────────┐
│         Resource Group                          │
│                                                  │
│  ┌──────────────────────────────────────────┐  │
│  │   Virtual Network (10.4.0.0/16)          │  │
│  │   ┌──────────────────────────────────┐   │  │
│  │   │ AKS Subnet (10.4.0.0/22)         │   │  │
│  │   │ - AKS Cluster (2 nodes)          │   │  │
│  │   │ - Workload Identity Enabled      │   │  │
│  │   │ - Web App Routing Enabled        │   │  │
│  │   └──────────────────────────────────┘   │  │
│  │   ┌──────────────────────────────────┐   │  │
│  │   │ AppGW Subnet (10.4.4.0/24)       │   │  │
│  │   │ - Delegated to                   │   │  │
│  │   │   ServiceNetworking/             │   │  │
│  │   │   trafficControllers             │   │  │
│  │   └──────────────────────────────────┘   │  │
│  └──────────────────────────────────────────┘  │
│                                                  │
│  ┌──────────────────────────────────────────┐  │
│  │   Azure Container Registry              │  │
│  └──────────────────────────────────────────┘  │
│                                                  │
│  ┌──────────────────────────────────────────┐  │
│  │   User Assigned Managed Identity        │  │
│  │   (for Application Gateway)              │  │
│  └──────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

## Parameters

Key parameters in `main.bicepparam`:

- `location`: Azure region (default: swedencentral)
- `baseName`: Base name for resources (default: appgw-demo)
- `kubernetesVersion`: AKS version (default: 1.34.7)
- `systemNodeSize`: VM size (default: Standard_B4as_v2)
- `systemNodeCount`: Number of nodes (default: 2)

## Application Gateway for Containers

Application Gateway for Containers (AGC) is Azure's modern, cloud-native application delivery service:

- **Azure-Native**: Deep integration with Azure networking and security
- **Gateway API Support**: Uses Kubernetes Gateway API standard
- **Scalable**: Automatically scales based on demand
- **Enterprise Features**: Ready for WAF, Azure Monitor, and advanced routing
- **Simplified Management**: Managed by Azure, no infrastructure to maintain

## Deployment

### Using Azure CLI

```bash
# Create resource group
az group create --name rg-03-appgw-containers-demo --location swedencentral

# Deploy Bicep template
az deployment group create \
  --resource-group rg-03-appgw-containers-demo \
  --name appgw-demo-deployment \
  --template-file main.bicep \
  --parameters main.bicepparam
```

### Get Deployment Outputs

```bash
az deployment group show \
  --resource-group rg-03-appgw-containers-demo \
  --name appgw-demo-deployment \
  --query properties.outputs
```

## Outputs

The deployment provides these outputs:

- `aksClusterName`: Name of the AKS cluster
- `aksClusterId`: Resource ID of the AKS cluster
- `oidcIssuerUrl`: OIDC issuer URL for workload identity
- `acrName`: Name of the ACR
- `acrLoginServer`: Login server URL for ACR
- `vnetName`: Virtual network name
- `aksSubnetId`: AKS subnet resource ID
- `appgwSubnetId`: Application Gateway subnet resource ID
- `agcIdentityClientId`: Client ID of the AGC managed identity
- `resourceGroupName`: Resource group name
- `nodeResourceGroupName`: AKS-managed infrastructure resource group name (`<resource-group>-infra`)

## Subnet Delegation

The Application Gateway for Containers subnet is delegated to `Microsoft.ServiceNetworking/trafficControllers`, which:
- Allows Azure to manage the subnet for Application Gateway resources
- Enables automatic provisioning of Application Gateway for Containers instances
- Provides network isolation for the gateway components

## Cost Estimation

Approximate monthly costs for the Sweden Central demos. Actual Azure pricing is region-dependent and may vary with usage:

- AKS Cluster: ~$70/month (2 x Standard_B4as_v2 nodes)
- Application Gateway for Containers: ~$40/month (base capacity)
- Azure Container Registry (Standard): ~$20/month
- Log Analytics: ~$5/month (minimal ingestion)
- Virtual Network: No charge (included)

**Total**: ~$205/month

💡 Remember to delete resources when not in use to avoid charges.

## Clean Up

```bash
# Delete the resource group (removes all resources)
az group delete --name rg-03-appgw-containers-demo --yes --no-wait
```

## Next Steps

After infrastructure deployment:
1. Get AKS credentials: `az aks get-credentials`
2. Install Application Gateway for Containers resources
3. Build and push the container image to ACR
4. Deploy Gateway API resources
5. Deploy the application with AGC annotations
