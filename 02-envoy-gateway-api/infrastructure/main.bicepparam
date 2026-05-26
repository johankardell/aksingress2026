using './main.bicep'

param location = 'swedencentral'
param baseName = 'envoy-demo'
param environment = 'demo'
param kubernetesVersion = '1.35.4'
param systemNodeSize = 'Standard_B4as_v2'
param systemNodeCount = 2
