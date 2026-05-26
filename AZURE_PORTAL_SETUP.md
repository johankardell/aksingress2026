# Azure Portal Kubernetes View Setup

This guide explains how to enable viewing Kubernetes resources (Deployments, Services, Ingress, etc.) in the Azure Portal.

## Prerequisites

You need your Azure AD user Object ID:
```bash
az ad signed-in-user show --query id -o tsv
```

Save this value - you'll need it for the configuration.

## What Needs to Change

To view Kubernetes resources in the Azure Portal, AKS clusters must be configured with:

1. **Azure AD Integration** - Managed Azure AD integration enabled
2. **Azure RBAC** - Azure RBAC for Kubernetes authorization enabled
3. **Role Assignments** - Your user needs specific Azure roles

## Current State

The demos are currently deployed with:
- ❌ Azure AD integration: **Disabled**
- ❌ Azure RBAC: **Disabled**
- ✅ Local Kubernetes RBAC: **Enabled**
- ✅ Admin credentials: **Working** (for deployments)

## Required Changes

### 1. Update Bicep Templates

Each demo's `infrastructure/main.bicep` needs these changes:

#### Add Parameter (at top of file)
```bicep
@description('Azure AD user object ID for RBAC admin access')
param userObjectId string
```

#### Enable Azure RBAC (in AKS resource properties)
```bicep
properties: {
  enableRBAC: true
  aadProfile: {
    managed: true
    enableAzureRBAC: true
    tenantID: subscription().tenantId
  }
  // ... rest of properties
}
```

#### Add Role Assignments (after AKS resource)
```bicep
// Azure Kubernetes Service Cluster User Role
resource aksClusterUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aksCluster.id, userObjectId, 'cluster-user')
  scope: aksCluster
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4abbcc35-e782-43d8-92c5-2d3f1bd2253f')
    principalId: userObjectId
    principalType: 'User'
  }
}

// Azure Kubernetes Service RBAC Admin
resource aksRbacAdminRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aksCluster.id, userObjectId, 'rbac-admin')
  scope: aksCluster
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '3498e952-d568-435e-9b2c-8d77e338d7f7')
    principalId: userObjectId
    principalType: 'User'
  }
}
```

### 2. Update Parameter Files

Each demo's `infrastructure/main.bicepparam` needs:

```bicep
using './main.bicep'

param location = 'swedencentral'
param kubernetesVersion = '1.34.7'
param vmSize = 'Standard_B4as_v2'
param nodeCount = 2
param userObjectId = '<YOUR_OBJECT_ID_HERE>' // <-- Replace with your Object ID
```

### 3. Files to Update

**Demo 01 - NGINX Ingress:**
- `01-nginx-ingress/infrastructure/main.bicep`
- `01-nginx-ingress/infrastructure/main.bicepparam`

**Demo 02 - Envoy Gateway:**
- `02-envoy-gateway-api/infrastructure/main.bicep`
- `02-envoy-gateway-api/infrastructure/main.bicepparam`

**Demo 03 - Application Gateway for Containers:**
- `03-appgw-for-containers/infrastructure/main.bicep`
- `03-appgw-for-containers/infrastructure/main.bicepparam`

## Deployment Instructions

### Option 1: Clean Redeploy (Recommended)

1. **Get your Object ID:**
   ```bash
   USER_ID=$(az ad signed-in-user show --query id -o tsv)
   echo "Your Object ID: $USER_ID"
   ```

2. **Update the Bicep files** as described above (or let me do it for you)

3. **Clean up existing deployments:**
   ```bash
   cd 01-nginx-ingress && ./scripts/cleanup.sh
   cd ../02-envoy-gateway-api && ./scripts/cleanup.sh
   cd ../03-appgw-for-containers && ./scripts/cleanup.sh
   ```

4. **Redeploy with new configuration:**
   ```bash
   cd 01-nginx-ingress && ./scripts/deploy.sh
   cd ../02-envoy-gateway-api && ./scripts/deploy.sh
   cd ../03-appgw-for-containers && ./scripts/deploy.sh
   ```

### Option 2: Update Existing Clusters

You can update existing clusters without deleting them:

```bash
# For each demo, run:
cd 01-nginx-ingress/infrastructure
az deployment group create \
  --resource-group rg-01-nginx-ingress-demo \
  --template-file main.bicep \
  --parameters main.bicepparam
```

**Note:** Enabling Azure RBAC on an existing cluster may cause a brief interruption.

## After Deployment

### 1. Verify Azure RBAC is Enabled

```bash
az aks show --resource-group rg-01-nginx-ingress-demo \
  --name <your-cluster-name> \
  --query aadProfile
```

Should show:
```json
{
  "enableAzureRbac": true,
  "managed": true,
  "tenantId": "<your-tenant-id>"
}
```

### 2. Get Credentials (Azure RBAC Mode)

```bash
# Use regular credentials (not --admin)
az aks get-credentials \
  --resource-group rg-01-nginx-ingress-demo \
  --name <your-cluster-name> \
  --overwrite-existing
```

### 3. Verify Portal Access

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to your AKS cluster
3. Click **"Kubernetes resources"** in the left menu
4. Select **"Workloads"** → You should see your deployments
5. Select **"Services and ingresses"** → You should see your services

## Troubleshooting

### Can't see resources in Portal

**Check role assignments:**
```bash
az role assignment list \
  --assignee <your-object-id> \
  --scope /subscriptions/<sub-id>/resourceGroups/<rg-name>/providers/Microsoft.ContainerService/managedClusters/<cluster-name>
```

You should see:
- Azure Kubernetes Service Cluster User Role
- Azure Kubernetes Service RBAC Cluster Admin

**Manually assign roles if needed:**
```bash
CLUSTER_ID=$(az aks show -g <rg-name> -n <cluster-name> --query id -o tsv)
USER_ID=$(az ad signed-in-user show --query id -o tsv)

# Cluster User Role
az role assignment create \
  --assignee $USER_ID \
  --role "Azure Kubernetes Service Cluster User Role" \
  --scope $CLUSTER_ID

# RBAC Admin Role  
az role assignment create \
  --assignee $USER_ID \
  --role "Azure Kubernetes Service RBAC Cluster Admin" \
  --scope $CLUSTER_ID
```

### Kubectl stops working

If kubectl stops working after enabling Azure RBAC:

```bash
# Get new credentials
az aks get-credentials \
  --resource-group <rg-name> \
  --name <cluster-name> \
  --overwrite-existing

# OR use admin credentials (bypasses Azure RBAC)
az aks get-credentials \
  --resource-group <rg-name> \
  --name <cluster-name> \
  --admin \
  --overwrite-existing
```

## Summary

**Time required:** ~30 minutes (includes cleanup + redeploy)

**Impact:** 
- ✅ Enables Azure Portal Kubernetes resource view
- ✅ Enables Azure RBAC for fine-grained permissions
- ⚠️ Changes authentication from local admin to Azure AD
- ⚠️ Requires role assignments for all users

**Next Steps:**
1. Let me know if you want me to update all the Bicep files for you
2. Or follow the manual steps above to update them yourself
3. Then cleanup and redeploy the demos
