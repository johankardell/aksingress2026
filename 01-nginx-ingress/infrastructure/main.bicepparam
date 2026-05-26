using './main.bicep'

param location = 'swedencentral'
param baseName = 'nginx-demo'
param environment = 'demo'
param kubernetesVersion = '1.34.7'
param systemNodeSize = 'Standard_B4as_v2'
param systemNodeCount = 2
param userObjectId = '8a264367-2c98-4953-b851-549a347c2b31'
