@description('Región Azure para el servidor de Azure Database for PostgreSQL Flexible Server.')
@allowed([
  'mexicocentral'
])
param location string = 'mexicocentral'

@description('Nombre del servidor de Azure Database for PostgreSQL Flexible Server destino para GEPER.')
param postgresServerName string

@description('Nombre de la base de datos PostgreSQL destino para la demostración en vivo (se mantiene vacía hasta el evento).')
param postgresDatabaseName string = 'geper'

@description('Nombre de la base de datos temporal para validación de conversión de esquema y PL/pgSQL.')
param postgresConversionValidationDbName string = 'geper_conversion_check'

@description('Nombre de la base de datos separada para el ensayo completo (rehearsal) sin tocar el destino de la demo.')
param postgresRehearsalDbName string = 'geper_rehearsal'

@description('Usuario administrador de PostgreSQL Flexible Server.')
param postgresAdminLogin string = 'geperpgadmin'

@description('Contraseña del administrador de PostgreSQL Flexible Server.')
@secure()
param postgresAdminPassword string

@description('Versión del motor PostgreSQL.')
@allowed([
  '15'
  '16'
  '17'
])
param postgresVersion string = '16'

@description('SKU del servidor PostgreSQL Flexible Server.')
param postgresSkuName string = 'Standard_B2s'

@description('Tier del servidor PostgreSQL Flexible Server.')
@allowed([
  'Burstable'
  'GeneralPurpose'
  'MemoryOptimized'
])
param postgresTier string = 'Burstable'

@description('Tamaño de almacenamiento en GiB para PostgreSQL Flexible Server.')
param postgresStorageSizeGB int = 32

@description('Dirección IPv4 pública estática de vm-geper-ora autorizada en el firewall de PostgreSQL.')
param allowedGeperVmPublicIp string = ''

@description('Nombre de la VNet compartida existente para vincular DNS privado y Private Endpoint.')
param existingVnetName string = 'vnet-legacy-lab-mxc'

@description('Nombre de la subred existente para Private Endpoints.')
param existingPrivateEndpointSubnetName string = 'snet-private-endpoints'

@description('Nombre del Azure Container Registry compartido existente.')
param existingAcrName string

@description('Nombre de la identidad administrada asignada por el usuario para la futura aplicación GEPER en Container Apps.')
param geperModernIdentityName string = 'id-geper-modern-aca'

@description('Tags aplicados al servidor PostgreSQL y recursos destino de GEPER.')
param tags object = {}

var acrPullRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')

resource existingVnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: existingVnetName
}

resource existingPeSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  parent: existingVnet
  name: existingPrivateEndpointSubnetName
}

resource existingAcr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: existingAcrName
}

resource geperModernIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: geperModernIdentityName
  location: location
  tags: union(tags, {
    application: 'GEPER'
    role: 'modernized-aca-identity'
  })
}

resource geperAcrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(existingAcr.id, geperModernIdentity.id, acrPullRoleId)
  scope: existingAcr
  properties: {
    roleDefinitionId: acrPullRoleId
    principalId: geperModernIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource pgServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-12-01-preview' = {
  name: postgresServerName
  location: location
  tags: union(tags, {
    application: 'GEPER'
    migrationTarget: 'postgresql-flexible-server'
  })
  sku: {
    name: postgresSkuName
    tier: postgresTier
  }
  properties: {
    version: postgresVersion
    administratorLogin: postgresAdminLogin
    administratorLoginPassword: postgresAdminPassword
    storage: {
      storageSizeGB: postgresStorageSizeGB
      autoGrow: 'Enabled'
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Enabled'
      tenantId: subscription().tenantId
    }
  }
}

resource geperDb 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-12-01-preview' = {
  parent: pgServer
  name: postgresDatabaseName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

resource geperConversionDb 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-12-01-preview' = {
  parent: pgServer
  name: postgresConversionValidationDbName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

resource geperRehearsalDb 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-12-01-preview' = {
  parent: pgServer
  name: postgresRehearsalDbName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

resource allowGeperVmRule 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-12-01-preview' = if (!empty(allowedGeperVmPublicIp)) {
  parent: pgServer
  name: 'Allow-GeperVm-StaticIp'
  properties: {
    startIpAddress: allowedGeperVmPublicIp
    endIpAddress: allowedGeperVmPublicIp
  }
}

resource pgPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.postgres.database.azure.com'
  location: 'global'
  tags: tags
}

resource pgPrivateDnsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: pgPrivateDnsZone
  name: 'link-pg-vnet'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: existingVnet.id
    }
  }
}

resource pgPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'pe-${postgresServerName}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: existingPeSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-${postgresServerName}'
        properties: {
          privateLinkServiceId: pgServer.id
          groupIds: [
            'postgresqlServer'
          ]
        }
      }
    ]
  }
}

resource pgPrivateDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: pgPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-postgres'
        properties: {
          privateDnsZoneId: pgPrivateDnsZone.id
        }
      }
    ]
  }
}

output postgresServerId string = pgServer.id
output postgresServerName string = pgServer.name
output postgresServerFqdn string = pgServer.properties.fullyQualifiedDomainName
output postgresDatabaseName string = geperDb.name
output postgresConversionValidationDbName string = geperConversionDb.name
output postgresRehearsalDbName string = geperRehearsalDb.name
output geperModernIdentityId string = geperModernIdentity.id
output geperModernIdentityName string = geperModernIdentity.name
output geperModernIdentityClientId string = geperModernIdentity.properties.clientId
output geperModernIdentityPrincipalId string = geperModernIdentity.properties.principalId
