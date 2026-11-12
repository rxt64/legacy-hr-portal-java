@description('Nombre de la zona DNS privada compartida (existing, aprovisionada por legacy-academic-portal-dotnet).')
param privateDnsZoneName string = 'lab.internal'

@description('IP privada del frontend del Load Balancer interno de GEPER, para el registro A geper.<privateDnsZoneName>.')
param geperLbFrontendIp string

@description('TTL en segundos del registro DNS.')
param dnsTtlSeconds int = 300

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: privateDnsZoneName
}

resource geperARecord 'Microsoft.Network/privateDnsZones/A@2024-06-01' = {
  parent: privateDnsZone
  name: 'geper'
  properties: {
    ttl: dnsTtlSeconds
    aRecords: [
      {
        ipv4Address: geperLbFrontendIp
      }
    ]
  }
}

output geperFqdn string = 'geper.${privateDnsZoneName}'
