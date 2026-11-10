@description('Nombre del perfil existente de Azure Front Door Standard creado por legacy-academic-portal-dotnet.')
param existingFrontDoorProfileName string

@description('Nombre del endpoint de Azure Front Door para GEPER.')
param geperEndpointName string

@description('FQDN o dirección IP del origen de GEPER (VM Oracle Linux con Spring Boot en puerto 8080).')
param geperOriginHostName string

@description('Puerto HTTP del origen de GEPER.')
param geperOriginHttpPort int = 8080

@description('Tags aplicados al endpoint de Azure Front Door de GEPER.')
param tags object = {}

resource existingFrontDoorProfile 'Microsoft.Cdn/profiles@2024-02-01' existing = {
  name: existingFrontDoorProfileName
}

resource geperEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2024-02-01' = {
  parent: existingFrontDoorProfile
  name: geperEndpointName
  location: 'Global'
  tags: union(tags, {
    application: 'GEPER'
  })
  properties: {
    enabledState: 'Enabled'
  }
}

resource geperOriginGroup 'Microsoft.Cdn/profiles/originGroups@2024-02-01' = {
  parent: existingFrontDoorProfile
  name: 'og-geper'
  properties: {
    sessionAffinityState: 'Enabled'
    trafficRestorationTimeToHealedOrNewEndpointsInMinutes: 0
    loadBalancingSettings: {
      sampleSize: 2
      successfulSamplesRequired: 1
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'GET'
      probeProtocol: 'Http'
      probeIntervalInSeconds: 15
    }
  }
}

resource geperOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2024-02-01' = {
  parent: geperOriginGroup
  name: 'origin-geper-vm'
  properties: {
    hostName: geperOriginHostName
    originHostHeader: geperOriginHostName
    httpPort: geperOriginHttpPort
    httpsPort: 443
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: false
  }
}

resource geperRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2024-02-01' = {
  parent: geperEndpoint
  name: 'route-geper-default'
  dependsOn: [
    geperOrigin
  ]
  properties: {
    originGroup: {
      id: geperOriginGroup.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
}

output frontDoorProfileName string = existingFrontDoorProfile.name
output geperEndpointName string = geperEndpoint.name
output geperEndpointHostName string = geperEndpoint.properties.hostName
output geperEndpointUrl string = 'https://${geperEndpoint.properties.hostName}/'
