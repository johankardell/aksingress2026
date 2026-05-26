# AKS Best Practices Configuration

## Overview

All three demos (01-nginx-ingress, 02-envoy-gateway-api, 03-agc-for-containers) have been updated with AKS best practices and production-ready settings.

## Enabled Features

### ✅ Security & Compliance

#### 1. **Image Cleaner** (NEW)
- **Purpose**: Automatically removes unused container images from nodes
- **Configuration**: Runs every 24 hours
- **Benefits**: 
  - Frees up disk space on nodes
  - Reduces security attack surface
  - Prevents node disk pressure issues
  
```bicep
imageCleaner: {
  enabled: true
  intervalHours: 24
}
```

#### 2. **Microsoft Defender for Containers** (NEW)
- **Purpose**: Runtime threat protection for containers
- **Configuration**: Integrated with Log Analytics
- **Benefits**:
  - Vulnerability scanning
  - Runtime threat detection
  - Compliance monitoring
  - Security recommendations

```bicep
defender: {
  logAnalyticsWorkspaceResourceId: logAnalytics.id
  securityMonitoring: {
    enabled: true
  }
}
```

#### 3. **Workload Identity**
- **Purpose**: Modern authentication using Azure AD identities for pods
- **Benefits**:
  - No credential management in pods
  - Azure RBAC integration
  - Better than pod-managed identities

```bicep
workloadIdentity: {
  enabled: true
}
```

#### 4. **OIDC Issuer**
- **Purpose**: Required for workload identity federation
- **Benefits**: Enables federated identity for pods

```bicep
oidcIssuerProfile: {
  enabled: true
}
```

#### 5. **Microsoft Entra ID Integration**
- **Purpose**: Managed Microsoft Entra ID authentication
- **Configuration**: Azure RBAC enabled and local AKS accounts disabled
- **Benefits**: 
  - No separate AAD app registration needed
  - Integrated with Azure Portal RBAC
  - Avoids admin kubeconfigs that bypass Entra ID and Azure RBAC

```bicep
disableLocalAccounts: true
aadProfile: {
  managed: true
  enableAzureRBAC: true
}
```

---

### ✅ Secrets & Configuration Management

#### 6. **Azure Key Vault Secrets Provider** (NEW)
- **Purpose**: Sync secrets from Azure Key Vault to Kubernetes
- **Configuration**: Auto-rotation enabled (2-minute poll interval)
- **Benefits**:
  - Centralized secret management
  - Automatic secret rotation
  - No secrets in code or YAML
  - Integration with Azure Key Vault

```bicep
azureKeyvaultSecretsProvider: {
  enabled: true
  config: {
    enableSecretRotation: 'true'
    rotationPollInterval: '2m'
  }
}
```

**Usage Example:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: app
    volumeMounts:
    - name: secrets-store
      mountPath: "/mnt/secrets-store"
      readOnly: true
  volumes:
  - name: secrets-store
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: "azure-kvname"
```

---

### ✅ Storage & Persistent Volumes

#### 7. **Azure Disk CSI Driver** (NEW)
- **Purpose**: Attach Azure Managed Disks as persistent volumes
- **Benefits**:
  - Production-grade persistent storage
  - Snapshot support
  - Dynamic provisioning

#### 8. **Azure Files CSI Driver** (NEW)
- **Purpose**: Mount Azure File Shares (SMB/NFS)
- **Benefits**:
  - ReadWriteMany support
  - Shared storage across pods
  - Backup integration

#### 9. **Azure Blob CSI Driver** (NEW)
- **Purpose**: Mount Azure Blob Storage containers
- **Benefits**:
  - Cost-effective object storage
  - Large data sets
  - ML/AI workloads

```bicep
storageProfile: {
  diskCSIDriver: {
    enabled: true
  }
  fileCSIDriver: {
    enabled: true
  }
  blobCSIDriver: {
    enabled: true
  }
}
```

**Usage Example:**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: azure-disk-pvc
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: managed-csi
  resources:
    requests:
      storage: 10Gi
```

---

### ✅ Monitoring & Observability

#### 10. **Azure Monitor Container Insights**
- **Purpose**: Container monitoring and log collection
- **Configuration**: Integrated with Log Analytics Workspace
- **Benefits**:
  - Container performance metrics
  - Log aggregation
  - Kubernetes events
  - Workload health monitoring

```bicep
omsagent: {
  enabled: true
  config: {
    logAnalyticsWorkspaceResourceID: logAnalytics.id
  }
}
```

**Metrics Available:**
- Node CPU/Memory utilization
- Pod CPU/Memory utilization
- Container restart counts
- Persistent volume usage
- Network metrics

---

### ✅ Networking

#### 11. **Azure CNI Networking**
- **Purpose**: Advanced networking with VNet integration
- **Benefits**:
  - Pods get VNet IPs
  - Direct pod-to-pod communication
  - Network security groups
  - Better performance than kubenet

#### 12. **Azure Network Policy**
- **Purpose**: Kubernetes network policy enforcement
- **Benefits**:
  - Pod-level firewall rules
  - Micro-segmentation
  - Zero-trust networking

```bicep
networkProfile: {
  networkPlugin: 'azure'
  networkPolicy: 'azure'
  serviceCidr: '10.x.0.0/16'
  dnsServiceIP: '10.x.0.10'
  loadBalancerSku: 'standard'
}
```

---

### ✅ Automatic Updates & Maintenance

#### 13. **Auto-Upgrade Channel (Stable)**
- **Purpose**: Automatic Kubernetes version updates
- **Configuration**: Stable channel (recommended for production)
- **Benefits**:
  - Automatic security patches
  - Kubernetes version upgrades
  - Reduced maintenance burden

```bicep
autoUpgradeProfile: {
  upgradeChannel: 'stable'
}
```

**Upgrade Channels:**
- `stable`: Recommended for production (what we use)
- `rapid`: Latest Kubernetes versions
- `patch`: Security patches only
- `node-image`: Node OS updates only
- `none`: Manual upgrades only

---

## Settings NOT Enabled (and Why)

### ❌ Azure Policy for AKS
- **Reason**: Adds overhead on Free tier clusters
- **Alternative**: Use Kubernetes admission controllers if needed
- **When to enable**: Production clusters with compliance requirements

### ❌ HTTP Application Routing
- **Status**: Deprecated by Microsoft
- **Alternative**: Use Gateway API (demos 02 & 03) or NGINX Ingress (demo 01)

### ❌ Open Service Mesh
- **Reason**: Adds complexity, not needed for these demos
- **When to use**: Microservices with advanced traffic management needs

### ❌ Azure Backup for AKS
- **Reason**: Not needed for demo/dev clusters
- **When to enable**: Production clusters with stateful workloads

---

## Cost Impact

All enabled features on Free tier AKS:

| Feature | Cost | Notes |
|---------|------|-------|
| Image Cleaner | Free | No additional cost |
| Defender for Containers | **~$7/vCore/month** | Billed per node vCore |
| Key Vault Secrets Provider | Free | Pay for Key Vault operations |
| CSI Drivers | Free | Pay for storage used |
| Azure Monitor | **~$2.50/GB** | Ingestion cost for logs |
| Auto-upgrade | Free | No additional cost |

**Estimated Monthly Cost (per cluster):**
- AKS Free tier: $0
- 2 x Standard_B4as_v2 nodes: ~$70
- Defender (2 nodes × 4 vCores): ~$56
- Azure Monitor (estimated 10GB): ~$25
- **Total: ~$151/month per cluster**

**To reduce costs:**
- Disable Defender for dev/test: `-$56`
- Reduce log retention: `-$10-15`
- Scale down to 1 node for demos: `-$35`

---

## Verification

After deploying, verify all features are enabled:

```bash
# Get cluster name
AKS_CLUSTER=$(az aks list --query "[0].name" -o tsv)
RG=$(az aks list --query "[0].resourceGroup" -o tsv)

# Check enabled features
az aks show -n $AKS_CLUSTER -g $RG --query "{
  imageCleaner: securityProfile.imageCleaner,
  defender: securityProfile.defender,
  workloadIdentity: securityProfile.workloadIdentity,
  kvSecretsProvider: addonProfiles.azureKeyvaultSecretsProvider,
  diskCSI: storageProfile.diskCSIDriver,
  fileCSI: storageProfile.fileCSIDriver,
  blobCSI: storageProfile.blobCSIDriver,
  autoUpgrade: autoUpgradeProfile.upgradeChannel
}" -o json
```

Expected output:
```json
{
  "autoUpgrade": "stable",
  "blobCSI": {
    "enabled": true
  },
  "defender": {
    "logAnalyticsWorkspaceResourceId": "/subscriptions/.../workspaces/...",
    "securityMonitoring": {
      "enabled": true
    }
  },
  "diskCSI": {
    "enabled": true
  },
  "fileCSI": {
    "enabled": true
  },
  "imageCleaner": {
    "enabled": true,
    "intervalHours": 24
  },
  "kvSecretsProvider": {
    "config": {
      "enableSecretRotation": "true",
      "rotationPollInterval": "2m"
    },
    "enabled": true
  },
  "workloadIdentity": {
    "enabled": true
  }
}
```

---

## Additional Recommendations

### For Production Clusters (Not in Free Tier)

1. **Enable Standard/Premium SKU**
   - Uptime SLA: 99.95%
   - Cost: +$73/month

2. **Enable Node Auto-Repair**
   - Automatic node health checks
   - Auto-replacement of unhealthy nodes

3. **Enable Cluster Autoscaler**
   - Automatic node scaling based on load
   - Cost optimization

4. **Enable Azure Backup**
   - Disaster recovery
   - Point-in-time restore

5. **Enable GitOps (Flux)**
   - Declarative configuration
   - Git as source of truth

6. **Configure Pod Security Standards**
   - Enforce security baselines
   - Prevent privileged containers

---

## Documentation Links

- [AKS Best Practices](https://learn.microsoft.com/azure/aks/best-practices)
- [Image Cleaner](https://learn.microsoft.com/azure/aks/image-cleaner)
- [Defender for Containers](https://learn.microsoft.com/azure/defender-for-cloud/defender-for-containers-introduction)
- [Key Vault Secrets Provider](https://learn.microsoft.com/azure/aks/csi-secrets-store-driver)
- [CSI Drivers](https://learn.microsoft.com/azure/aks/csi-storage-drivers)
- [Workload Identity](https://learn.microsoft.com/azure/aks/workload-identity-overview)

---

**Last Updated:** May 21, 2026  
**Applies to:** All three demos  
**AKS API Version:** 2024-01-01
