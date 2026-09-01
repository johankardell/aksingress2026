// Parameters
@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Base name for all resources')
param baseName string = 'afdgw-demo'

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
  Demo: 'AFD-AppGw'
  ManagedBy: 'Bicep'
}

// Variables
var aksClusterName = '${baseName}-aks-${uniqueString(resourceGroup().id)}'
var logAnalyticsName = '${baseName}-logs-${uniqueString(resourceGroup().id)}'
var vnetName = '${baseName}-vnet-${uniqueString(resourceGroup().id)}'
var nodeResourceGroupName = '${resourceGroup().name}-infra'
var prometheusCollectorName = 'msprom-${uniqueString(resourceGroup().id)}'
var appGatewayName = '${baseName}-agw-${uniqueString(resourceGroup().id)}'
var appGatewayPublicIpName = '${baseName}-agw-pip'
var frontDoorProfileName = '${baseName}-afd'
var frontDoorEndpointName = '${baseName}-endpoint-${uniqueString(resourceGroup().id)}'
// Front Door WAF policy names must be alphanumeric only.
var frontDoorWafPolicyName = replace('${baseName}wafpolicy${uniqueString(resourceGroup().id)}', '-', '')

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.6.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'aks-subnet'
        properties: {
          addressPrefix: '10.6.0.0/22'
        }
      }
      {
        name: 'appgw-subnet'
        properties: {
          addressPrefix: '10.6.4.0/24'
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

// Public IP for Application Gateway (Front Door origin)
resource appGatewayPublicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: appGatewayPublicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: toLower('${baseName}-agw-${uniqueString(resourceGroup().id)}')
    }
  }
}

// Classic Application Gateway v2 (WAF is enforced upstream by Azure Front Door).
// This gateway starts with a minimal placeholder configuration; the AGIC add-on
// (enabled on the AKS cluster below) reconciles listeners/rules/pools from
// Kubernetes Ingress resources after deployment.
resource appGateway 'Microsoft.Network/applicationGateways@2023-11-01' = {
  name: appGatewayName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
    }
    autoscaleConfiguration: {
      minCapacity: 1
      maxCapacity: 3
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: vnet.properties.subnets[1].id
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGatewayFrontendIP'
        properties: {
          publicIPAddress: {
            id: appGatewayPublicIp.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port80'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'defaultBackendPool'
        properties: {}
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'defaultHttpSettings'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
        }
      }
    ]
    httpListeners: [
      {
        name: 'defaultListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, 'appGatewayFrontendIP')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, 'port80')
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'defaultRoutingRule'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, 'defaultListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGatewayName, 'defaultBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGatewayName, 'defaultHttpSettings')
          }
        }
      }
    ]
  }
}

// AKS Cluster with the Application Gateway Ingress Controller (AGIC) add-on
// attached to the existing Application Gateway above.
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
      serviceCidr: '10.7.0.0/16'
      dnsServiceIP: '10.7.0.10'
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
      ingressApplicationGateway: {
        enabled: true
        config: {
          applicationGatewayId: appGateway.id
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

// Azure Front Door (Premium) profile fronting the Application Gateway with WAF enabled
resource frontDoorProfile 'Microsoft.Cdn/profiles@2024-02-01' = {
  name: frontDoorProfileName
  location: 'global'
  tags: tags
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
}

resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2024-02-01' = {
  parent: frontDoorProfile
  name: frontDoorEndpointName
  location: 'global'
  tags: tags
  properties: {
    enabledState: 'Enabled'
  }
}

resource frontDoorOriginGroup 'Microsoft.Cdn/profiles/originGroups@2024-02-01' = {
  parent: frontDoorProfile
  name: 'appgw-origin-group'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/health'
      probeRequestType: 'GET'
      probeProtocol: 'Http'
      probeIntervalInSeconds: 30
    }
  }
}

resource frontDoorOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2024-02-01' = {
  parent: frontDoorOriginGroup
  name: 'appgw-origin'
  properties: {
    hostName: appGatewayPublicIp.properties.dnsSettings.fqdn
    httpPort: 80
    httpsPort: 443
    originHostHeader: appGatewayPublicIp.properties.dnsSettings.fqdn
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
  }
}

resource frontDoorRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2024-02-01' = {
  parent: frontDoorEndpoint
  name: 'default-route'
  dependsOn: [
    frontDoorOrigin
  ]
  properties: {
    originGroup: {
      id: frontDoorOriginGroup.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Disabled'
  }
}

// Front Door WAF policy with managed rule sets, in Prevention mode
resource frontDoorWafPolicy 'Microsoft.Network/frontdoorWebApplicationFirewallPolicies@2024-02-01' = {
  name: frontDoorWafPolicyName
  location: 'global'
  tags: tags
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: 'Prevention'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'Microsoft_DefaultRuleSet'
          ruleSetVersion: '2.1'
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '1.0'
        }
      ]
    }
  }
}

resource frontDoorSecurityPolicy 'Microsoft.Cdn/profiles/securityPolicies@2024-02-01' = {
  parent: frontDoorProfile
  name: 'waf-security-policy'
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      wafPolicy: {
        id: frontDoorWafPolicy.id
      }
      associations: [
        {
          domains: [
            {
              id: frontDoorEndpoint.id
            }
          ]
          patternsToMatch: [
            '/*'
          ]
        }
      ]
    }
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
output appGatewaySubnetId string = vnet.properties.subnets[1].id
output appGatewayName string = appGateway.name
output appGatewayId string = appGateway.id
output appGatewayPublicIpAddress string = appGatewayPublicIp.properties.ipAddress
output appGatewayPublicIpFqdn string = appGatewayPublicIp.properties.dnsSettings.fqdn
output frontDoorProfileName string = frontDoorProfile.name
output frontDoorEndpointName string = frontDoorEndpoint.name
output frontDoorEndpointHostName string = frontDoorEndpoint.properties.hostName
output frontDoorWafPolicyName string = frontDoorWafPolicy.name
output resourceGroupName string = resourceGroup().name
output nodeResourceGroupName string = aks.properties.nodeResourceGroup
