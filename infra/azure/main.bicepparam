using './main.bicep'

// Archivo de ejemplo sin secretos ni IPs privadas.
// Requiere haber desplegado previamente la infraestructura compartida de
// legacy-academic-portal-dotnet/infra/azure/main.bicep (grupo de recursos y VNet).

param location = 'mexicocentral'
param existingResourceGroupName = 'rg-legacy-apps-demo-mxc'
param existingVnetName = 'vnet-legacy-lab-mxc'
param existingSubnetName = 'snet-geper'
param presenterAllowedCidr = ''
param enablePublicIp = true
param geperVmName = 'vm-geper-ora'
param geperVmSize = 'Standard_D4s_v5'
param geperImagePublisher = 'Oracle'
param geperImageOffer = 'oracle-database'
param geperImageSku = 'oracle_db_12_2_0_1_ee'
param geperImageVersion = '12.2.01'
param osDiskSku = 'StandardSSD_LRS'
param osDiskSizeGb = 128
param dataDiskSku = 'StandardSSD_LRS'
param dataDiskSizeGb = 128
param adminUsername = 'geperadmin'
param sshPublicKey = readEnvironmentVariable('GEPER_VM_SSH_PUBLIC_KEY', '')
param adminPassword = readEnvironmentVariable('GEPER_VM_ADMIN_PASSWORD', '')
param enableFrontDoor = true
param enablePostgresMigrationTarget = true
param enablePrivateAccess = true
param existingPrivateDnsZoneName = 'lab.internal'
