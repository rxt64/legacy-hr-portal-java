@description('Región Azure para la VM y discos de GEPER.')
@allowed([
  'mexicocentral'
])
param location string = 'mexicocentral'

@description('Nombre de la máquina virtual Linux de GEPER.')
param vmName string

@description('Tamaño de la VM de GEPER.')
param vmSize string = 'Standard_D4s_v5'

@description('Nombre de la VNet compartida existente.')
param existingVnetName string

@description('Nombre de la subred existente para GEPER.')
param existingSubnetName string

@description('ID del NSG de GEPER.')
param nsgId string

@description('Crear IP pública estática para el túnel SSH restringido.')
param enablePublicIp bool = true

@description('Publisher de la imagen Linux/Oracle.')
param imagePublisher string = 'Oracle'

@description('Offer de la imagen Linux/Oracle.')
param imageOffer string = 'oracle-database'

@description('SKU de la imagen Linux/Oracle.')
param imageSku string = 'oracle_db_12_2_0_1_ee'

@description('Versión de la imagen Linux/Oracle.')
param imageVersion string = '12.2.01'

@description('SKU del disco de sistema operativo.')
@allowed([
  'StandardSSD_LRS'
  'Premium_LRS'
])
param osDiskSku string = 'StandardSSD_LRS'

@description('Tamaño en GiB del disco de sistema operativo.')
param osDiskSizeGb int = 128

@description('Nombre del disco administrado persistente para datos de Oracle.')
param dataDiskName string

@description('SKU del disco de datos persistente.')
@allowed([
  'StandardSSD_LRS'
  'Premium_LRS'
])
param dataDiskSku string = 'StandardSSD_LRS'

@description('Tamaño en GiB del disco de datos persistente.')
param dataDiskSizeGb int = 128

@description('Nombre del usuario administrador Linux.')
param adminUsername string

@description('Clave pública SSH del administrador Linux.')
param sshPublicKey string = ''

@description('Contraseña opcional del administrador Linux.')
@secure()
param adminPassword string = ''

@description('Tags aplicados a los recursos de cómputo, disco y red de GEPER.')
param tags object = {}

resource existingVnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: existingVnetName
}

resource geperSubnetWithNsg 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  parent: existingVnet
  name: existingSubnetName
  properties: {
    addressPrefix: '10.42.2.0/24'
    networkSecurityGroup: {
      id: nsgId
    }
  }
}

resource pip 'Microsoft.Network/publicIPAddresses@2023-11-01' = if (enablePublicIp) {
  name: 'pip-${vmName}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: 'geper-vm-${take(uniqueString(resourceGroup().id, vmName), 8)}'
    }
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: 'nic-${vmName}'
  location: location
  tags: tags
  properties: {
    networkSecurityGroup: {
      id: nsgId
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: geperSubnetWithNsg.id
          }
          publicIPAddress: enablePublicIp ? {
            id: pip!.id
          } : null
        }
      }
    ]
  }
}

resource oracleDataDisk 'Microsoft.Compute/disks@2023-10-02' = {
  name: dataDiskName
  location: location
  tags: union(tags, {
    dataRole: 'geper-oracle-persistent-data'
  })
  sku: {
    name: dataDiskSku
  }
  properties: {
    creationData: {
      createOption: 'Empty'
    }
    diskSizeGB: dataDiskSizeGb
  }
}

var useSshKeys = !empty(sshPublicKey)
var disablePasswordAuth = useSshKeys && empty(adminPassword)

resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: vmName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: !empty(adminPassword) ? adminPassword : null
      linuxConfiguration: {
        disablePasswordAuthentication: disablePasswordAuth
        provisionVMAgent: true
        ssh: useSshKeys ? {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        } : null
      }
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: imageVersion
      }
      osDisk: {
        name: 'osdisk-${vmName}'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        deleteOption: 'Detach'
        diskSizeGB: osDiskSizeGb
        managedDisk: {
          storageAccountType: osDiskSku
        }
      }
      dataDisks: [
        {
          lun: 0
          name: oracleDataDisk.name
          createOption: 'Attach'
          caching: 'None'
          deleteOption: 'Detach'
          managedDisk: {
            id: oracleDataDisk.id
          }
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

output vmId string = vm.id
output vmName string = vm.name
output privateIpAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output publicIpAddress string = enablePublicIp ? pip!.properties.ipAddress : ''
output publicIpFqdn string = enablePublicIp ? pip!.properties.dnsSettings.fqdn : ''
output dataDiskId string = oracleDataDisk.id
output principalId string = vm.identity.principalId
