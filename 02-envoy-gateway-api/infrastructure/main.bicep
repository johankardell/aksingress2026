// Parameters
@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Base name for all resources')
param baseName string = 'envoy-demo'

@description('Environment name (dev, test, prod)')
param environment string = 'demo'

@description('AKS Kubernetes version')
param kubernetesVersion string = '1.35.4'

@description('System node pool VM size')
param systemNodeSize string = 'Standard_B4as_v2'

@description('System node pool node count')
@minValue(1)
@maxValue(5)
param systemNodeCount int = 2

@description('Azure AD user object ID for RBAC admin access')
param userObjectId string

@description('Tags for all resources')
param tags object = {
  Environment: environment
  Demo: 'Gateway-API-Envoy'
  ManagedBy: 'Bicep'
}

// Variables
var aksClusterName = '${baseName}-aks-${uniqueString(resourceGroup().id)}'
var acrName = replace('${baseName}acr${uniqueString(resourceGroup().id)}', '-', '')
var logAnalyticsName = '${baseName}-logs-${uniqueString(resourceGroup().id)}'
var nodeResourceGroupName = '${resourceGroup().name}-infra'

// Log Analytics Workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Azure Container Registry
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

// AKS Cluster with Gateway API enabled
resource aks 'Microsoft.ContainerService/managedClusters@2024-01-01' = {
  name: aksClusterName
  location: location
  tags: tags
  sku: {
    name: 'Base'
    tier: 'Free'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: aksClusterName
    nodeResourceGroup: nodeResourceGroupName
    enableRBAC: true
    
    // Agent pools
    agentPoolProfiles: [
      {
        name: 'systempool'
        count: systemNodeCount
        vmSize: systemNodeSize
        osType: 'Linux'
        mode: 'System'
        type: 'VirtualMachineScaleSets'
        enableAutoScaling: false
        maxPods: 110
        osDiskSizeGB: 128
        osDiskType: 'Managed'
      }
    ]
    
    // Networking
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      serviceCidr: '10.3.0.0/16'
      dnsServiceIP: '10.3.0.10'
      loadBalancerSku: 'standard'
    }
    
    // Add-ons
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalytics.id
        }
      }
      azurePolicy: {
        enabled: false
      }
      azureKeyvaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation: 'true'
          rotationPollInterval: '2m'
        }
      }
    }
    
    // Security
    disableLocalAccounts: true
    aadProfile: {
      managed: true
      enableAzureRBAC: true
      tenantID: subscription().tenantId
    }
    
    // Workload Identity (modern practice)
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
      imageCleaner: {
        enabled: true
        intervalHours: 24
      }
      defender: {
        logAnalyticsWorkspaceResourceId: logAnalytics.id
        securityMonitoring: {
          enabled: true
        }
      }
    }
    
    // Storage Drivers (CSI)
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
    
    // OIDC Issuer (required for workload identity)
    oidcIssuerProfile: {
      enabled: true
    }
    
    autoUpgradeProfile: {
      upgradeChannel: 'stable'
    }
  }
}

// Role assignment: AKS to ACR
resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, aks.id, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: aks.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}

// Role assignment: User - Azure Kubernetes Service Cluster User Role
resource userClusterUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aks.id, userObjectId, 'AKSClusterUser')
  scope: aks
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4abbcc35-e782-43d8-92c5-2d3f1bd2253f') // Azure Kubernetes Service Cluster User Role
    principalId: userObjectId
    principalType: 'User'
  }
}

// Role assignment: User - Azure Kubernetes Service RBAC Cluster Admin
resource userClusterAdminRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aks.id, userObjectId, 'AKSClusterAdmin')
  scope: aks
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b') // Azure Kubernetes Service RBAC Cluster Admin
    principalId: userObjectId
    principalType: 'User'
  }
}

// Outputs
output aksClusterName string = aks.name
output aksClusterId string = aks.id
output aksFqdn string = aks.properties.fqdn
output oidcIssuerUrl string = aks.properties.oidcIssuerProfile.issuerURL
output acrName string = acr.name
output acrLoginServer string = acr.properties.loginServer
output resourceGroupName string = resourceGroup().name
output nodeResourceGroupName string = aks.properties.nodeResourceGroup
