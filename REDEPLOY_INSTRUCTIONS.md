# Redeploy Instructions for Azure Portal Access

Your Bicep files have been updated to enable Azure Portal Kubernetes resource viewing.

## What Was Changed

✅ All 6 files updated:
- `01-nginx-ingress/infrastructure/main.bicep` - Added Azure RBAC + role assignments
- `01-nginx-ingress/infrastructure/main.bicepparam` - Uses deployment-time Object ID
- `02-envoy-gateway-api/infrastructure/main.bicep` - Added Azure RBAC + role assignments
- `02-envoy-gateway-api/infrastructure/main.bicepparam` - Uses deployment-time Object ID
- `03-appgw-for-containers/infrastructure/main.bicep` - Added Azure RBAC + role assignments
- `03-appgw-for-containers/infrastructure/main.bicepparam` - Uses deployment-time Object ID

**Your Object ID:** `<your-object-id>`

## Changes Made

1. **Added `userObjectId` parameter** to all Bicep templates
2. **Enabled Azure RBAC** in `aadProfile`:
   ```bicep
   aadProfile: {
     managed: true
     enableAzureRBAC: true
     tenantID: subscription().tenantId
   }
   ```
3. **Added role assignments** for your user:
   - Azure Kubernetes Service Cluster User Role
   - Azure Kubernetes Service RBAC Cluster Admin

## Redeploy Steps

### Option 1: Clean Redeploy (Recommended - ~30 minutes)

Delete and recreate everything:

```bash
# Clean up all demos
cd /home/johan/dev/github/aksingress2026
./01-nginx-ingress/scripts/cleanup.sh
./02-envoy-gateway-api/scripts/cleanup.sh
./03-appgw-for-containers/scripts/cleanup.sh

# Redeploy all demos with Azure RBAC
./01-nginx-ingress/scripts/deploy.sh
./02-envoy-gateway-api/scripts/deploy.sh
./03-appgw-for-containers/scripts/deploy.sh
```

The deployment scripts automatically resolve your signed-in user's Object ID with:

```bash
az ad signed-in-user show --query id -o tsv
```

### Option 2: Update Existing Clusters (Faster - ~10 minutes)

Update in-place without deleting:

```bash
cd /home/johan/dev/github/aksingress2026

# Update Demo 01
cd 01-nginx-ingress/infrastructure
az deployment group create \
  --resource-group rg-01-nginx-ingress-demo \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --parameters userObjectId=<your-object-id>

# Update Demo 02
cd ../../02-envoy-gateway-api/infrastructure
az deployment group create \
  --resource-group rg-02-envoy-gateway-demo \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --parameters userObjectId=<your-object-id>

# Update Demo 03
cd ../../03-appgw-for-containers/infrastructure
az deployment group create \
  --resource-group rg-03-appgw-containers-demo \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --parameters userObjectId=<your-object-id>
```

## After Redeployment

### 1. Get New Credentials

For each cluster, get credentials with Microsoft Entra ID auth and Azure RBAC:

```bash
# Demo 01
az aks get-credentials \
  --resource-group rg-01-nginx-ingress-demo \
  --name <cluster-name> \
  --overwrite-existing

# Demo 02
az aks get-credentials \
  --resource-group rg-02-envoy-gateway-demo \
  --name <cluster-name> \
  --overwrite-existing

# Demo 03
az aks get-credentials \
  --resource-group rg-03-appgw-containers-demo \
  --name <cluster-name> \
  --overwrite-existing
```

### 2. Verify kubectl Access

```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

If you get permission errors, verify the Azure role assignments below. These
demos disable local AKS accounts, so admin kubeconfigs are not available during
normal deployment.

### 3. Test Azure Portal Access

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to any AKS cluster
3. Click **"Kubernetes resources"** in left menu
4. Select **"Workloads"** 
   - ✅ Should see deployments, pods, replica sets
5. Select **"Services and ingresses"**
   - ✅ Should see services and ingress resources
6. Select **"Configuration"**
   - ✅ Should see ConfigMaps and Secrets

## Troubleshooting

### Can't see resources in Portal

Check role assignments:
```bash
CLUSTER_NAME="<your-cluster-name>"
RG_NAME="<your-rg-name>"
CLUSTER_ID=$(az aks show -g $RG_NAME -n $CLUSTER_NAME --query id -o tsv)

az role assignment list \
  --assignee <your-object-id> \
  --scope $CLUSTER_ID
```

Should show:
- Azure Kubernetes Service Cluster User Role
- Azure Kubernetes Service RBAC Cluster Admin

### kubectl not working

Get fresh credentials:
```bash
az aks get-credentials \
  --resource-group <rg-name> \
  --name <cluster-name> \
  --overwrite-existing
```

Admin kubeconfigs bypass Azure RBAC and are intentionally unavailable for these
demos because local AKS accounts are disabled. Treat re-enabling local accounts
as a separate break-glass operation only, then disable them again immediately.

## Summary

- ✅ **What**: Enabled Azure Portal Kubernetes resource viewing
- ✅ **How**: Azure AD + Azure RBAC + Role Assignments
- ⏱️ **Time**: 10-30 minutes depending on option
- 🔧 **Impact**: Changes authentication from local to Azure AD
- 🎯 **Benefit**: View and manage K8s resources in Azure Portal

Choose **Option 1** (clean redeploy) for a fresh start, or **Option 2** (update) to keep existing deployments.
