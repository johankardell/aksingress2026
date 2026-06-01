// Parameters
@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Base name for all resources')
param baseName string = 'agc-demo'

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

@description('Name of the shared Azure Container Registry')
param sharedAcrName string

@description('Resource group that contains shared demo resources, including Azure Container Registry, Azure Monitor workspace, and Azure Managed Grafana')
param sharedAcrResourceGroupName string = 'rg-aksdemo-shared'

@description('Name of the shared Azure Monitor workspace used by managed Prometheus')
param sharedAzureMonitorWorkspaceName string = 'aksdemo-amw-${uniqueString(subscription().id, location)}'

@description('Name of the shared Azure Managed Grafana instance')
param sharedGrafanaName string = 'aksgraf${uniqueString(subscription().id, location)}'

@description('Day of week for AKS auto-upgrade and node OS maintenance windows')
@allowed([
  'Monday'
  'Tuesday'
  'Wednesday'
  'Thursday'
  'Friday'
  'Saturday'
  'Sunday'
])
param maintenanceDayOfWeek string = 'Sunday'

@description('Start time for AKS maintenance windows in HH:mm using the configured UTC offset, for example 02:00')
param maintenanceStartTime string = '02:00'

@description('Duration in hours for AKS maintenance windows')
@minValue(4)
@maxValue(24)
param maintenanceDurationHours int = 4

@description('Fixed UTC offset for AKS maintenance windows. +01:00 aligns to Sweden standard time; use +02:00 for Swedish summer time.')
param maintenanceUtcOffset string = '+01:00'

@description('Tags for all resources')
param tags object = {
  Environment: environment
  Demo: 'AGC-for-Containers'
  ManagedBy: 'Bicep'
}

// Variables
var aksClusterName = '${baseName}-aks-${uniqueString(resourceGroup().id)}'
var logAnalyticsName = '${baseName}-logs-${uniqueString(resourceGroup().id)}'
var vnetName = '${baseName}-vnet-${uniqueString(resourceGroup().id)}'
var nodeResourceGroupName = '${resourceGroup().name}-infra'
var prometheusCollectorName = 'msprom-${uniqueString(resourceGroup().id)}'

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.4.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'aks-subnet'
        properties: {
          addressPrefix: '10.4.0.0/22'
        }
      }
      {
        name: 'agc-subnet'
        properties: {
          addressPrefix: '10.4.4.0/24'
          delegations: [
            {
              name: 'Microsoft.ServiceNetworking/trafficControllers'
              properties: {
                serviceName: 'Microsoft.ServiceNetworking/trafficControllers'
              }
            }
          ]
        }
      }
    ]
  }
}

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

// Shared Azure Container Registry
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: sharedAcrName
  scope: resourceGroup(sharedAcrResourceGroupName)
}

// Shared Azure Monitor workspace and Azure Managed Grafana
module observability '../../shared/infrastructure/observability.bicep' = {
  name: 'shared-observability-${baseName}'
  scope: resourceGroup(sharedAcrResourceGroupName)
  params: {
    location: location
    azureMonitorWorkspaceName: sharedAzureMonitorWorkspaceName
    grafanaName: sharedGrafanaName
    userObjectId: userObjectId
    tags: union(tags, {
      Shared: 'true'
    })
  }
}

// User Assigned Managed Identity for Application Gateway for Containers
resource agcIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${baseName}-agc-identity'
  location: location
  tags: tags
}

// AKS Cluster prepared for Application Gateway for Containers
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
        vnetSubnetID: vnet.properties.subnets[0].id
      }
    ]
    
    // Networking
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      serviceCidr: '10.5.0.0/16'
      dnsServiceIP: '10.5.0.10'
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
    
    // Azure Monitor managed Prometheus
    azureMonitorProfile: {
      metrics: {
        enabled: true
        kubeStateMetrics: {
          metricAnnotationsAllowList: ''
          metricLabelsAllowlist: ''
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
    
    // Workload Identity
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
    
    // OIDC Issuer
    oidcIssuerProfile: {
      enabled: true
    }
    
    autoUpgradeProfile: {
      upgradeChannel: 'stable'
    }
  }
}

// Data collection for Azure Monitor managed Prometheus
resource prometheusDataCollectionEndpoint 'Microsoft.Insights/dataCollectionEndpoints@2022-06-01' = {
  name: prometheusCollectorName
  location: location
  kind: 'Linux'
  tags: tags
  properties: {
    networkAcls: {
      publicNetworkAccess: 'Enabled'
    }
  }
}

resource prometheusDataCollectionRule 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: prometheusCollectorName
  location: location
  tags: tags
  properties: {
    dataCollectionEndpointId: prometheusDataCollectionEndpoint.id
    dataSources: {
      prometheusForwarder: [
        {
          name: 'PrometheusDataSource'
          streams: [
            'Microsoft-PrometheusMetrics'
          ]
          labelIncludeFilter: {}
        }
      ]
    }
    destinations: {
      monitoringAccounts: [
        {
          accountResourceId: observability.outputs.azureMonitorWorkspaceId
          name: 'MonitoringAccount1'
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-PrometheusMetrics'
        ]
        destinations: [
          'MonitoringAccount1'
        ]
      }
    ]
  }
}

resource prometheusDataCollectionRuleAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = {
  name: prometheusCollectorName
  scope: aks
  properties: {
    dataCollectionRuleId: prometheusDataCollectionRule.id
    description: 'Routes managed Prometheus metrics from this AKS cluster to the shared Azure Monitor workspace.'
  }
}

// AKS maintenance schedule for Kubernetes auto-upgrades
resource autoUpgradeMaintenance 'Microsoft.ContainerService/managedClusters/maintenanceConfigurations@2024-01-01' = {
  parent: aks
  name: 'aksManagedAutoUpgradeSchedule'
  properties: {
    maintenanceWindow: {
      schedule: {
        weekly: {
          dayOfWeek: maintenanceDayOfWeek
          intervalWeeks: 1
        }
      }
      durationHours: maintenanceDurationHours
      utcOffset: maintenanceUtcOffset
      startTime: maintenanceStartTime
    }
  }
}

// AKS maintenance schedule for managed node OS image upgrades
resource nodeImageMaintenance 'Microsoft.ContainerService/managedClusters/maintenanceConfigurations@2024-01-01' = {
  parent: aks
  name: 'aksManagedNodeOSUpgradeSchedule'
  properties: {
    maintenanceWindow: {
      schedule: {
        weekly: {
          dayOfWeek: maintenanceDayOfWeek
          intervalWeeks: 1
        }
      }
      durationHours: maintenanceDurationHours
      utcOffset: maintenanceUtcOffset
      startTime: maintenanceStartTime
    }
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
output azureMonitorWorkspaceName string = observability.outputs.azureMonitorWorkspaceName
output azureMonitorWorkspaceId string = observability.outputs.azureMonitorWorkspaceId
output grafanaName string = observability.outputs.grafanaName
output grafanaEndpoint string = observability.outputs.grafanaEndpoint
output vnetName string = vnet.name
output vnetId string = vnet.id
output aksSubnetId string = vnet.properties.subnets[0].id
output agcSubnetId string = vnet.properties.subnets[1].id
output agcIdentityName string = agcIdentity.name
output agcIdentityId string = agcIdentity.id
output agcIdentityClientId string = agcIdentity.properties.clientId
output agcIdentityPrincipalId string = agcIdentity.properties.principalId
output resourceGroupName string = resourceGroup().name
output nodeResourceGroupName string = aks.properties.nodeResourceGroup
