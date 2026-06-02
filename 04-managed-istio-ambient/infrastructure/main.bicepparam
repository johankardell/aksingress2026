using './main.bicep'

param location = 'northeurope'
param baseName = 'istio-ambient-demo'
param environment = 'demo'
param kubernetesVersion = '1.35.4'
param systemNodeSize = 'Standard_B4as_v2'
param systemNodeCount = 2
param maintenanceDayOfWeek = 'Sunday'
param maintenanceStartTime = '02:00'
param maintenanceDurationHours = 4
param maintenanceUtcOffset = '+01:00'
param userObjectId = '00000000-0000-0000-0000-000000000000'
// Static validation placeholder; scripts/deploy-infra.sh overrides this with the shared ACR created or reused in rg-aksdemo-shared.
param sharedAcrName = 'setsharedacrname'
param sharedAcrResourceGroupName = 'rg-aksdemo-shared'
