# Azure Portal RBAC Configuration - Summary

## Overview

All three demos (Demo 01, Demo 02, Demo 03) have been configured with **Azure RBAC** for Kubernetes authorization, providing centralized access management through Azure AD and Azure Portal.

## RBAC Mode: Azure RBAC

**Setting:** `enableAzureRBAC: true`

All clusters use **Azure RBAC** instead of traditional Kubernetes RBAC. This provides:

✅ **Centralized Access Management** - Manage permissions through Azure Portal  
✅ **Azure AD Integration** - Use existing Azure AD users and groups  
✅ **Audit Logging** - All authorization decisions logged in Azure  
✅ **Consistent with Azure** - Same permission model as other Azure resources  
✅ **Portal Integration** - View workloads directly in Azure Portal  

### Azure RBAC vs Kubernetes RBAC

| Feature | Azure RBAC | Kubernetes RBAC |
|---------|-----------|-----------------|
| **Authorization** | Azure AD + Azure RBAC | Kubernetes ClusterRoles/RoleBindings |
| **Management** | Azure Portal, CLI, ARM | kubectl, YAML files |
| **Audit Trail** | Azure Activity Log | Kubernetes Audit Log |
| **Scope** | Azure subscription level | Kubernetes cluster level |
| **Portal View** | ✅ Full workload view | ❌ Limited view |

## Changes Made

### 1. Bicep Templates Updated

**All Demos:** `/01-nginx-ingress/infrastructure/main.bicep`, `/02-envoy-gateway-api/infrastructure/main.bicep`, `/03-appgw-for-containers/infrastructure/main.bicep`

**Enabled Azure RBAC:**
```bicep
aadProfile: {
  managed: true
  enableAzureRBAC: true      // ← Azure RBAC enabled
  tenantID: subscription().tenantId
}
```

**Added User Role Assignments:**

```bicep
// Role assignment: User - Azure Kubernetes Service Cluster User Role
resource userClusterUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aks.id, userObjectId, 'AKSClusterUser')
  scope: aks
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4abbcc35-e782-43d8-92c5-2d3f1bd2253f')
    principalId: userObjectId
    principalType: 'User'
  }
}

// Role assignment: User - Azure Kubernetes Service RBAC Cluster Admin
resource userClusterAdminRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aks.id, userObjectId, 'AKSClusterAdmin')
  scope: aks
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b')
    principalId: userObjectId
    principalType: 'User'
  }
}
```

### 2. Deployment Scripts Updated

**All Demos:** `/scripts/deploy.sh`

Changes:
- Automatically retrieves the current user's Azure AD Object ID
- Passes it as a parameter override to the Bicep deployment
- Initializes path variables (`SCRIPT_DIR`, `REPO_ROOT`) early to avoid path navigation issues
- Updated step numbering (Demo 02: 10 steps, Demo 03: 11 steps)

Key addition:
```bash
# Get current user object ID for RBAC
echo -e "${YELLOW}[4/10] Getting user information for RBAC...${NC}"
USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
echo -e "${GREEN}✓ User Object ID: ${USER_OBJECT_ID}${NC}"

# Deploy with user object ID override
az deployment group create \
  --parameters userObjectId=$USER_OBJECT_ID \
  ...
```

### 3. Additional Fixes (Demo 03)

**App Routing Fix:**
- Fixed the App Routing enable logic to properly handle "already enabled" scenario
- Changed from hard failure to success when App Routing is already enabled
- Better error detection and user feedback

```bash
# Enable app routing (safe to run if already enabled)
APPROUTING_OUTPUT=$(az aks approuting enable --resource-group $RESOURCE_GROUP --name $AKS_NAME 2>&1) || true

if echo "$APPROUTING_OUTPUT" | grep -q "already enabled"; then
  echo -e "${GREEN}✓ App Routing is already enabled${NC}"
elif echo "$APPROUTING_OUTPUT" | grep -q "error\|Error\|ERROR"; then
  echo -e "${RED}✗ Error enabling App Routing:${NC}"
  echo "$APPROUTING_OUTPUT"
  exit 1
else
  echo -e "${GREEN}✓ App Routing enabled${NC}"
fi
```

## Azure Roles Assigned

### Azure Kubernetes Service Cluster User Role
- **ID:** `4abbcc35-e782-43d8-92c5-2d3f1bd2253f`
- **Purpose:** Allows users to list and get cluster credentials
- **Scope:** AKS cluster
- **Required for:** Accessing cluster via kubectl or Azure Portal

### Azure Kubernetes Service RBAC Cluster Admin  
- **ID:** `b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b`
- **Purpose:** Full admin access to all Kubernetes resources in the cluster (via Azure RBAC)
- **Scope:** AKS cluster
- **Enables:** 
  - Viewing workloads, services, pods, and other resources in Azure Portal
  - Full kubectl access to all namespaces
  - Creating/deleting any Kubernetes resource
  - Managing RBAC permissions

**Important:** This role provides cluster-wide admin permissions through Azure RBAC, not traditional Kubernetes ClusterRoleBindings.

## Azure Portal Access

After deploying with these changes, you can:

1. Navigate to the Azure Portal
2. Go to your AKS cluster (e.g., `nginx-demo-aks-*`, `envoy-demo-aks-*`, `appgw-demo-aks-*`)
3. Click on **Workloads** in the left menu
4. View **Deployments**, **Pods**, **ReplicaSets**, etc.
5. Click on **Services and ingresses**
6. View **Services**, **Gateways**, **HTTPRoutes**, etc.
7. Click on **Configuration**
8. View **ConfigMaps**, **Secrets**
9. Click on **Storage**
10. View **Persistent Volumes**, **Persistent Volume Claims**

**All authorization is managed through Azure RBAC** - no need to manage Kubernetes ClusterRoleBindings or RoleBindings.

## How User Object ID is Obtained

The deployment scripts automatically get the currently signed-in user's Azure AD Object ID:

```bash
USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
```

This is then passed to the Bicep template as a parameter override, which takes precedence over the default value in `main.bicepparam`.

## Parameter Files

Both parameter files still contain a default user object ID:
- `/02-envoy-gateway-api/infrastructure/main.bicepparam`
- `/03-appgw-for-containers/infrastructure/main.bicepparam`

```bicep
param userObjectId = '8a264367-2c98-4953-b851-549a347c2b31'
```

However, the deployment scripts override this with the current user's ID, ensuring the correct user gets RBAC permissions regardless of who runs the script.

## Validation

All changes have been validated:
- ✅ Bicep templates build successfully without errors
- ✅ Deployment scripts pass syntax validation
- ✅ Role definition IDs are correct
- ✅ Path navigation issues resolved
- ✅ Step numbering is consistent

## Testing

To test the changes:

1. **Demo 02:**
   ```bash
   cd /home/johan/dev/github/aksingress2026/02-envoy-gateway-api
   ./scripts/deploy.sh
   ```

2. **Demo 03:**
   ```bash
   cd /home/johan/dev/github/aksingress2026/03-appgw-for-containers
   ./scripts/deploy.sh
   ```

After deployment, verify Azure Portal access by navigating to the AKS cluster and checking that the **Workloads** and **Services and ingresses** sections are accessible.

## Notes

- The `userObjectId` parameter is required and must be a valid Azure AD Object ID
- The deployment scripts automatically retrieve this for the signed-in user
- Manual deployments using `az deployment group create` directly should specify `--parameters userObjectId=<your-object-id>`
- The RBAC role assignments are idempotent and safe to redeploy
- Cleanup scripts are unaffected by these changes

---

**Date:** May 21, 2026
**Affected Demos:** Demo 02, Demo 03
**Status:** ✅ Complete and Validated
