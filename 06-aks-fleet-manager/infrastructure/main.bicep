@description('Azure region for the Fleet Manager resource')
param location string = resourceGroup().location

@description('Name of the Azure Kubernetes Fleet Manager resource')
@minLength(1)
@maxLength(63)
param fleetName string = 'aks-ingress-demo-fleet'

@description('Environment name')
param environment string = 'demo'

@description('Tags for the Fleet Manager resource')
param tags object = {
  Environment: environment
  Demo: 'AKS-Fleet-Manager'
  ManagedBy: 'Bicep'
}

resource fleet 'Microsoft.ContainerService/fleets@2025-03-01' = {
  name: fleetName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
}

output fleetName string = fleet.name
output fleetId string = fleet.id
output fleetPrincipalId string = fleet.identity.principalId
