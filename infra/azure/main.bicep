targetScope = 'subscription'

@description('Región Azure obligatoria para todos los recursos regionales de GEPER.')
@allowed([
  'mexicocentral'
])
param location string = 'mexicocentral'

@description('Nombre del grupo de recursos existente aprovisionado por legacy-academic-portal-dotnet.')
param existingResourceGroupName string = 'rg-legacy-apps-demo-mxc'

@description('Nombre de la red virtual compartida existente en el grupo de recursos.')
param existingVnetName string = 'vnet-legacy-lab-mxc'

@description('Nombre de la subred existente dedicada a GEPER dentro de la VNet compartida.')
param existingSubnetName string = 'snet-geper'

@description('CIDR IPv4 público verificado del presentador para túnel SSH (ej. 198.51.100.25/32). Vacío deshabilita la regla de entrada SSH desde Internet. Prohibido 0.0.0.0/0 o *.')
param presenterAllowedCidr string = ''

@description('Habilitar IP pública estática para el túnel SSH autenticado del presentador.')
param enablePublicIp bool = true

@description('Nombre de la máquina virtual Linux + Oracle Database 12c R2 para GEPER.')
param geperVmName string = 'vm-geper-ora'

@description('Tamaño de la VM de GEPER en Mexico Central (4 vCPU, 16 GiB RAM, compatible con Gen1/Gen2).')
param geperVmSize string = 'Standard_D4s_v5'

@description('Publisher de la imagen Linux/Oracle de GEPER.')
param geperImagePublisher string = 'Oracle'

@description('Offer de la imagen Linux/Oracle de GEPER (oracle-database para imagen oficial 12.2.0.1 o Oracle-Linux para instalación desde linuxx64_12201_database.zip).')
param geperImageOffer string = 'oracle-database'

@description('SKU de la imagen Linux/Oracle de GEPER (oracle_db_12_2_0_1_ee, oracle_db_12_2_0_1_se o 7.6).')
param geperImageSku string = 'oracle_db_12_2_0_1_ee'

@description('Versión exacta de la imagen Linux/Oracle de GEPER.')
param geperImageVersion string = '12.2.01'

@description('SKU del disco de sistema operativo de GEPER.')
@allowed([
  'StandardSSD_LRS'
  'Premium_LRS'
])
param osDiskSku string = 'StandardSSD_LRS'

@description('Tamaño en GiB del disco de sistema operativo de GEPER.')
param osDiskSizeGb int = 128

@description('SKU del disco administrado persistente para datos de Oracle (oradata/GEPERPDB).')
@allowed([
  'StandardSSD_LRS'
  'Premium_LRS'
])
param dataDiskSku string = 'StandardSSD_LRS'

@description('Tamaño en GiB del disco administrado persistente para datos de Oracle.')
param dataDiskSizeGb int = 128

@description('Usuario administrador Linux de la VM de GEPER.')
param adminUsername string = 'geperadmin'

@description('Clave pública SSH para el usuario administrador (recomendado para el túnel SSH del presentador).')
param sshPublicKey string = ''

@description('Contraseña opcional de respaldo para el usuario administrador.')
@secure()
param adminPassword string = ''

@description('Habilitar publicación de GEPER en el perfil compartido de Azure Front Door Standard.')
param enableFrontDoor bool = true

@description('Nombre del perfil compartido existente de Azure Front Door Standard (vacío usa el nombre determinista del grupo de recursos).')
param existingFrontDoorProfileName string = ''

@description('Nombre del endpoint de Azure Front Door para GEPER (vacío usa el nombre determinista).')
param geperFrontDoorEndpointName string = ''

@description('Tags genéricos aplicados a todos los recursos de GEPER.')
param tags object = {
  project: 'legacy-modernization-lab'
  environment: 'demo'
  purpose: 'academic-and-hr-legacy-baseline'
  managedBy: 'bicep'
}

resource existingRg 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: existingResourceGroupName
}

module geperNsg 'modules/geper-nsg.bicep' = {
  name: 'deploy-geper-nsg'
  scope: existingRg
  params: {
    location: location
    nsgName: 'nsg-${geperVmName}'
    presenterAllowedCidr: presenterAllowedCidr
    enableFrontDoorBackend: enableFrontDoor
    tags: union(tags, {
      application: 'GEPER'
    })
  }
}

module geperVm 'modules/geper-vm.bicep' = {
  name: 'deploy-geper-vm'
  scope: existingRg
  params: {
    location: location
    vmName: geperVmName
    vmSize: geperVmSize
    existingVnetName: existingVnetName
    existingSubnetName: existingSubnetName
    nsgId: geperNsg.outputs.nsgId
    enablePublicIp: enablePublicIp
    imagePublisher: geperImagePublisher
    imageOffer: geperImageOffer
    imageSku: geperImageSku
    imageVersion: geperImageVersion
    osDiskSku: osDiskSku
    osDiskSizeGb: osDiskSizeGb
    dataDiskName: 'disk-${geperVmName}-oradata'
    dataDiskSku: dataDiskSku
    dataDiskSizeGb: dataDiskSizeGb
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    adminPassword: adminPassword
    tags: union(tags, {
      application: 'GEPER'
      stack: 'java8-springboot27-oracle12cR2'
    })
  }
}

var effectiveFrontDoorProfileName = !empty(existingFrontDoorProfileName) ? existingFrontDoorProfileName : 'afd-legacy-lab-${take(uniqueString(existingRg.id), 8)}'
var effectiveGeperEndpointName = !empty(geperFrontDoorEndpointName) ? geperFrontDoorEndpointName : 'geper-lab-${take(uniqueString(existingRg.id), 8)}'

module geperFrontDoor 'modules/geper-frontdoor.bicep' = if (enableFrontDoor && enablePublicIp) {
  name: 'deploy-geper-frontdoor'
  scope: existingRg
  params: {
    existingFrontDoorProfileName: effectiveFrontDoorProfileName
    geperEndpointName: effectiveGeperEndpointName
    geperOriginHostName: geperVm.outputs.publicIpFqdn
    geperOriginHttpPort: 8080
    tags: tags
  }
}

output resourceGroupName string = existingRg.name
output location string = location
output geperVmName string = geperVm.outputs.vmName
output geperPrivateIp string = geperVm.outputs.privateIpAddress
output geperPublicIp string = geperVm.outputs.publicIpAddress
output geperPublicFqdn string = geperVm.outputs.publicIpFqdn
output geperDataDiskId string = geperVm.outputs.dataDiskId
output frontDoorProfileName string = (enableFrontDoor && enablePublicIp) ? geperFrontDoor!.outputs.frontDoorProfileName : ''
output geperFrontDoorEndpointHostName string = (enableFrontDoor && enablePublicIp) ? geperFrontDoor!.outputs.geperEndpointHostName : ''
output geperFrontDoorUrl string = (enableFrontDoor && enablePublicIp) ? geperFrontDoor!.outputs.geperEndpointUrl : ''
