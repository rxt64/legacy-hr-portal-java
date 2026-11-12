@description('Región Azure del Load Balancer interno.')
@allowed([
  'mexicocentral'
])
param location string = 'mexicocentral'

@description('Nombre del Load Balancer interno de GEPER.')
param lbName string = 'lb-geper-internal'

@description('Nombre de la VNet compartida existente (aprovisionada por legacy-academic-portal-dotnet).')
param existingVnetName string

@description('Nombre de la subred existente de GEPER donde se asigna el frontend privado del Load Balancer (asignación dinámica).')
param existingSubnetName string

@description('IP privada de la VM de GEPER (vm-geper-ora) ya existente, para agregarla al pool de backend sin modificar su NIC.')
param geperVmPrivateIp string

@description('Puerto HTTP de la aplicación GEPER (Spring Boot, listener :::8080).')
param appPort int = 8080

@description('Tags de los recursos.')
param tags object = {}

var frontendName = 'fe-geper-private'
var backendPoolName = 'pool-geper-vm'
var probeName = 'probe-geper-http'
var ruleName = 'rule-geper-http'

resource existingVnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: existingVnetName
}

resource existingGeperSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  parent: existingVnet
  name: existingSubnetName
}

resource lb 'Microsoft.Network/loadBalancers@2024-07-01' = {
  name: lbName
  location: location
  sku: {
    name: 'Standard'
  }
  tags: tags
  properties: {
    frontendIPConfigurations: [
      {
        name: frontendName
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: existingGeperSubnet.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: backendPoolName
        properties: {
          loadBalancerBackendAddresses: [
            {
              name: 'addr-vm-geper-ora'
              properties: {
                ipAddress: geperVmPrivateIp
                virtualNetwork: {
                  id: existingVnet.id
                }
              }
            }
          ]
        }
      }
    ]
    probes: [
      {
        name: probeName
        properties: {
          protocol: 'Tcp'
          port: appPort
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
    loadBalancingRules: [
      {
        name: ruleName
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, frontendName)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, backendPoolName)
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', lbName, probeName)
          }
          protocol: 'Tcp'
          frontendPort: appPort
          backendPort: appPort
          idleTimeoutInMinutes: 4
          enableFloatingIP: false
          disableOutboundSnat: false
        }
      }
    ]
  }
}

output lbName string = lb.name
output lbId string = lb.id
output frontendPrivateIp string = lb.properties.frontendIPConfigurations[0].properties.privateIPAddress
