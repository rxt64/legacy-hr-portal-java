// Herramienta del PRESENTADOR para la conversión asistida por IA de Oracle -> PostgreSQL
// (wizard "Oracle to PostgreSQL migration" de la extensión PostgreSQL de VS Code).
// NO es parte del laboratorio en vivo: no procesa filas de datos, solo metadatos del
// diccionario de Oracle (DDL) para generar el esquema PostgreSQL equivalente.
//
// Bloqueo regional real y documentado: Microsoft.CognitiveServices (Microsoft Foundry /
// Azure OpenAI) NO está disponible en Mexico Central (no figura entre las ubicaciones
// soportadas por el resource provider). Por eso este módulo, a diferencia del resto del
// laboratorio, se despliega en una región distinta (por defecto South Central US, la más
// cercana a México con disponibilidad confirmada). Todo el resto de la infraestructura del
// laboratorio permanece en mexicocentral sin cambios.

@description('Región Azure para el recurso de Microsoft Foundry. Mexico Central NO soporta Microsoft.CognitiveServices; por eso el valor por defecto es South Central US (la más cercana a México con soporte confirmado).')
@allowed([
  'southcentralus'
  'eastus2'
  'centralus'
  'westus3'
])
param location string = 'southcentralus'

@description('Nombre del recurso de Microsoft Foundry (Cognitive Services, kind AIServices).')
param foundryAccountName string

@description('Nombre del despliegue del modelo dentro del recurso de Foundry.')
param modelDeploymentName string = 'gpt-5-2-oracle-migration'

@description('Nombre del modelo a desplegar (requerido por el wizard de migración Oracle->PostgreSQL de la extensión PostgreSQL de VS Code).')
param modelName string = 'gpt-5.2'

@description('Versión exacta del modelo publicada en el catálogo de Microsoft Foundry.')
param modelVersion string = '2025-12-11'

@description('Capacidad del despliegue en miles de tokens por minuto (TPM). 1000 = 1,000,000 TPM, el máximo disponible por defecto en esta suscripción sin solicitar aumento de cuota (verificado vía "az cognitiveservices usage list"). La documentación oficial recomienda cuota superior a 1,000,000 TPM; este es el límite exacto disponible sin trámite adicional.')
param modelCapacity int = 1000

@description('SKU del despliegue del modelo.')
@allowed([
  'GlobalStandard'
])
param modelSkuName string = 'GlobalStandard'

@description('Nombre del proyecto de Microsoft Foundry a crear dentro del recurso (ver nota de limitación conocida más abajo: el proyecto NO se crea con este template, se documenta aquí solo como referencia del nombre a usar en el paso CLI posterior).')
param foundryProjectName string = 'geper-oracle-migration'

@description('Object ID (principal) de la cuenta Microsoft Entra ID que usará el wizard de migración (VS Code) para autenticarse contra Microsoft Foundry. El wizard oficial requiere el rol "Foundry User" (antes "Azure AI User"); además se otorga "Cognitive Services OpenAI User" para permitir llamadas de inferencia directas (verificación/pruebas fuera del wizard).')
param presenterPrincipalId string

@description('Tags aplicados al recurso de Foundry, identificándolo como herramienta del presentador y no parte del laboratorio.')
param tags object = {}

resource foundryAccount 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: foundryAccountName
  location: location
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  tags: union(tags, {
    purpose: 'presenter-tool-oracle-to-postgres-schema-conversion'
    partOfLab: 'false'
    application: 'GEPER'
  })
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: foundryAccountName
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
    allowProjectManagement: true
  }
}

var foundryUserRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '53ca6127-db72-4b80-b1b0-d745d6d5456d')
var cogSvcOpenAiUserRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')

resource foundryUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundryAccount.id, presenterPrincipalId, foundryUserRoleId)
  scope: foundryAccount
  properties: {
    roleDefinitionId: foundryUserRoleId
    principalId: presenterPrincipalId
    principalType: 'User'
  }
}

resource cogSvcOpenAiUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundryAccount.id, presenterPrincipalId, cogSvcOpenAiUserRoleId)
  scope: foundryAccount
  properties: {
    roleDefinitionId: cogSvcOpenAiUserRoleId
    principalId: presenterPrincipalId
    principalType: 'User'
  }
}

// NOTA DE LIMITACIÓN CONOCIDA (verificada empíricamente, no es un supuesto):
// Declarar aquí un recurso `Microsoft.CognitiveServices/accounts/projects` que sea hijo de
// `foundryAccount` en el MISMO despliegue falla de forma consistente y reproducible con
// "RequestConflict: Another operation is being performed on the parent resource", incluso
// en despliegues idempotentes donde no hay ningún cambio real pendiente. Se intentó 5 veces
// (incluida una ejecución aislada sin cambios en la cuenta) y falló las 5. Esto no es un
// error transitorio: es una limitación del resource provider de Microsoft.CognitiveServices
// al combinar actualizaciones de cuenta y creación de proyecto hijo en un solo template.
//
// Por eso el proyecto se crea en un paso CLI SEPARADO, ejecutado una sola vez después de
// este despliegue (comando verificado funcionando, ver README o GUIA-COMPLETA-STEP-BY-STEP-DEMO.md):
//
//   az cognitiveservices account project create \
//     --name <foundryAccountName> \
//     --resource-group <resourceGroup> \
//     --project-name <foundryProjectName> \
//     --location <location> \
//     --display-name "GEPER Oracle to PostgreSQL migration" \
//     --assign-identity
//
// El endpoint de proyecto resultante (confirmado real, no construido a mano) tiene la forma:
//   https://<foundryAccountName>.services.ai.azure.com/api/projects/<foundryProjectName>

resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: foundryAccount
  name: modelDeploymentName
  sku: {
    name: modelSkuName
    capacity: modelCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: modelName
      version: modelVersion
    }
  }
}

output foundryAccountId string = foundryAccount.id
output foundryAccountName string = foundryAccount.name
output foundryEndpoint string = foundryAccount.properties.endpoint
output foundryProjectEndpointExpected string = 'https://${foundryAccountName}.services.ai.azure.com/api/projects/${foundryProjectName}'
output modelDeploymentName string = modelDeployment.name
// La API Key NO se expone como output (ver requisito "secretos fuera del repositorio y de
// los outputs"); se obtiene aparte con:
//   az cognitiveservices account keys list --name <foundryAccountName> --resource-group <rg>
