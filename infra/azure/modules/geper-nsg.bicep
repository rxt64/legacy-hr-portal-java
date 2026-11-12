@description('Región Azure para el NSG de GEPER.')
@allowed([
  'mexicocentral'
])
param location string = 'mexicocentral'

@description('Nombre del Network Security Group de GEPER.')
param nsgName string

@description('CIDR IPv4 público del presentador para SSH (puerto 22). Vacío deshabilita la regla de entrada SSH desde Internet. Prohibido 0.0.0.0/0 o *.')
param presenterAllowedCidr string = ''

@description('Permitir tráfico entrante desde el Service Tag AzureFrontDoor.Backend hacia el puerto 8080 de GEPER.')
param enableFrontDoorBackend bool = true

@description('Habilitar regla explicita de entrada para el health probe del Load Balancer interno (requerida en este tenant: la regla default AllowAzureLoadBalancerInBound no fue suficiente en pruebas reales).')
param enableInternalLbProbe bool = true

@description('Tags aplicados al NSG.')
param tags object = {}

var hasValidPresenterCidr = !empty(presenterAllowedCidr) && presenterAllowedCidr != '0.0.0.0/0' && presenterAllowedCidr != '*' && presenterAllowedCidr != 'Internet'

var sshAllowRules = hasValidPresenterCidr ? [
  {
    name: 'Allow-Presenter-SSH-Inbound'
    properties: {
      description: 'Permite SSH exclusivamente desde la IP publica verificada del presentador para tunel local.'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '22'
      sourceAddressPrefix: presenterAllowedCidr
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 100
      direction: 'Inbound'
    }
  }
] : []

var frontDoorAllowRules = enableFrontDoorBackend ? [
  {
    name: 'Allow-AzureFrontDoor-HTTP-Inbound'
    properties: {
      description: 'Permite trafico HTTP (8080) entrante exclusivamente desde Azure Front Door (Service Tag AzureFrontDoor.Backend).'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '8080'
      sourceAddressPrefix: 'AzureFrontDoor.Backend'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 150
      direction: 'Inbound'
    }
  }
] : []

var internalLbProbeRules = enableInternalLbProbe ? [
  {
    name: 'Allow-AzureLoadBalancer-Probe-Inbound'
    properties: {
      description: 'Permite explicitamente el health probe del Load Balancer interno (Service Tag AzureLoadBalancer). La regla default AllowAzureLoadBalancerInBound (65001) no fue suficiente en este tenant durante pruebas reales; esta regla explicita a prioridad 140 lo garantiza.'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '*'
      sourceAddressPrefix: 'AzureLoadBalancer'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 140
      direction: 'Inbound'
    }
  }
] : []

var baseDenyRules = [
  {
    name: 'Deny-Internet-Web-Inbound'
    properties: {
      description: 'Bloquea exposicion publica de puertos web (80/443/8080) hacia GEPER.'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRanges: [
        '80'
        '443'
        '8080'
      ]
      sourceAddressPrefix: 'Internet'
      destinationAddressPrefix: '*'
      access: 'Deny'
      priority: 200
      direction: 'Inbound'
    }
  }
  {
    name: 'Deny-Internet-Oracle-Inbound'
    properties: {
      description: 'Bloquea exposicion publica de Oracle Net Listener (1521) y EM (5500) desde Internet.'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRanges: [
        '1521'
        '5500'
      ]
      sourceAddressPrefix: 'Internet'
      destinationAddressPrefix: '*'
      access: 'Deny'
      priority: 210
      direction: 'Inbound'
    }
  }
]

resource geperNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: concat(sshAllowRules, frontDoorAllowRules, internalLbProbeRules, baseDenyRules)
  }
}

output nsgId string = geperNsg.id
output nsgName string = geperNsg.name
