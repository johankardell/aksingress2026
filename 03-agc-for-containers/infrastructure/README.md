# AGC Demo - Infrastructure

This folder contains Bicep infrastructure-as-code templates for deploying AKS with Application Gateway for Containers and supporting Azure resources. The Azure Container Registry is shared across demos and is created or reused by the deployment script in `rg-aksdemo-shared`.

## Resources Deployed

- **Virtual Network**: With dedicated subnets for AKS and Application Gateway for Containers
- **AKS Cluster**: Prepared for AGC with Workload Identity, Microsoft Entra ID authentication, Azure RBAC, and local accounts disabled
- **Web Application Firewall Policy**: AGC-supported DRS 2.1 policy for route protection
- **Shared Azure Container Registry reference**: Existing registry in `rg-aksdemo-shared` used for the demo application image
- **Shared Azure Monitor workspace and Azure Managed Grafana**: Created or reused in `rg-aksdemo-shared` for managed Prometheus metrics from all demos
- **Log Analytics Workspace**: For Container Insights logs and diagnostics
- **Managed Prometheus collection**: AKS `azureMonitorProfile.metrics` plus a data collection rule that sends metrics to the shared Azure Monitor workspace
- **Managed Identities**: System-assigned for AKS, user-assigned for Application Gateway for Containers
- **RBAC Role Assignments**: User AKS access; AKS `AcrPull` on the shared registry and AGC identity roles are assigned by `scripts/deploy-infra.sh` after the AKS infrastructure resource group exists

## Key Features

This infrastructure showcases Azure-native ingress capabilities:

- **Application Gateway for Containers**: Azure-managed application delivery controller
- **ALB Controller**: Installed with the Application Gateway for Containers Helm chart
- **Virtual Network Integration**: Dedicated subnet delegation for Application Gateway
- **Workload Identity**: Modern authentication for Azure services
- **Microsoft Entra ID + Azure RBAC**: User access without admin kubeconfigs
- **Azure Monitor Integration**: Native observability
- **Azure WAF Policy**: Prevention-mode managed ruleset that can be attached through the ALB Controller

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
│  │   └──────────────────────────────────┘   │  │
│  │   ┌──────────────────────────────────┐   │  │
│  │   │ AGC Subnet (10.4.4.0/24)       │   │  │
│  │   │ - Delegated to                   │   │  │
│  │   │   ServiceNetworking/             │   │  │
│  │   │   trafficControllers             │   │  │
│  │   └──────────────────────────────────┘   │  │
│  └──────────────────────────────────────────┘  │
│                                                  │
│  ┌──────────────────────────────────────────┐  │
│  │ Shared ACR (rg-aksdemo-shared)          │  │
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
- `baseName`: Base name for resources (default: agc-demo)
- `kubernetesVersion`: AKS version (default: 1.35.4)
- `systemNodeSize`: VM size (default: Standard_B4as_v2)
- `systemNodeCount`: Number of nodes (default: 2)
- `maintenanceDayOfWeek`: AKS auto-upgrade and node OS image maintenance day (default: Sunday)
- `maintenanceStartTime`: AKS maintenance start time in HH:mm in the configured UTC offset (default: 02:00)
- `maintenanceDurationHours`: AKS maintenance window duration in hours (default: 4)
- `maintenanceUtcOffset`: Fixed AKS maintenance window UTC offset for Sweden local expectations (default: +01:00; use +02:00 for Swedish summer time)

The AKS Kubernetes auto-upgrade and managed node OS image schedules use the same weekly nighttime maintenance window.

## Application Gateway for Containers

Application Gateway for Containers (AGC) is Azure's modern, cloud-native application delivery service:

- **Azure-Native**: Deep integration with Azure networking and security
- **Gateway API Support**: Uses Kubernetes Gateway API standard
- **Scalable**: Automatically scales based on demand
- **Enterprise Features**: Ready for WAF, Azure Monitor, and advanced routing
- **Managed Data Plane**: Azure operates the ingress data plane outside the cluster

## Deployment

### Using Azure CLI

```bash
# Create resource group
az group create --name rg-03-agc-containers-demo --location swedencentral

# Create or reuse the shared resource group/ACR, then deploy Bicep template.
# The template also creates or reuses shared Grafana and Azure Monitor workspace resources there.
source ../../shared/scripts/acr-image.sh
ACR_NAME=$(ensure_shared_acr)
USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
az deployment group create \
  --resource-group rg-03-agc-containers-demo \
  --name agc-demo-deployment \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --parameters userObjectId="$USER_OBJECT_ID" \
  --parameters sharedAcrName="$ACR_NAME" \
  --parameters sharedAcrResourceGroupName="$SHARED_ACR_RESOURCE_GROUP"
```

### Get Deployment Outputs

```bash
az deployment group show \
  --resource-group rg-03-agc-containers-demo \
  --name agc-demo-deployment \
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
- `vnetName`: Virtual network name
- `aksSubnetId`: AKS subnet resource ID
- `agcSubnetId`: Application Gateway subnet resource ID
- `agcIdentityName`: Name of the AGC managed identity
- `agcIdentityClientId`: Client ID of the AGC managed identity
- `wafPolicyId`: Resource ID of the Azure WAF policy attached by the Kubernetes demo
- `resourceGroupName`: Resource group name
- `nodeResourceGroupName`: AKS-managed infrastructure resource group name (`<resource-group>-infra`)

## Subnet Delegation

The AGC subnet is delegated to `Microsoft.ServiceNetworking/trafficControllers`, which:
- Allows Azure to manage the subnet for Application Gateway resources
- Enables automatic provisioning of Application Gateway for Containers instances
- Provides network isolation for the gateway components

## Cost Estimation

Costs are region- and usage-dependent. Use the [Azure pricing calculator](https://azure.microsoft.com/pricing/calculator/) for Sweden Central and include:

| Resource | Billing basis |
|----------|---------------|
| AKS | Two `Standard_B4as_v2` nodes; Free tier has no control-plane charge |
| Application Gateway for Containers | Gateway hours plus capacity units |
| Web Application Firewall | WAF-enabled gateway and request processing |
| Shared observability and ACR | Allocate shared registry, Grafana, ingestion, and retention costs across demos |

💡 Remember to delete resources when not in use to avoid charges.

## Clean Up

```bash
# Delete the resource group (removes all resources)
az group delete --name rg-03-agc-containers-demo --yes --no-wait
```

This permanently deletes demo-owned Log Analytics workspaces and then deletes only the demo resource group. Delete `rg-aksdemo-shared` separately only after all demos are cleaned up and you no longer need the shared ACR, Azure Monitor workspace, or Grafana dashboards.

## Next Steps

After infrastructure deployment:
1. Get AKS credentials: `az aks get-credentials`
2. Install the ALB Controller with Helm
3. Build the shared container image in ACR
4. Create the `ApplicationLoadBalancer` resource
5. Deploy Gateway API resources and the application with AGC annotations
