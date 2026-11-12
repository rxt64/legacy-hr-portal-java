using './foundry-oracle-migration.bicep'

// Archivo de ejemplo sin secretos. Herramienta del PRESENTADOR para la conversión asistida
// por IA de Oracle -> PostgreSQL (wizard de la extensión PostgreSQL de VS Code). NO forma
// parte del laboratorio en vivo.
//
// Bloqueo regional real: Microsoft.CognitiveServices (Microsoft Foundry) no está disponible
// en Mexico Central. Por eso, a diferencia del resto del laboratorio, este recurso se
// despliega en South Central US (verificado: 1,000,000 TPM de cuota gpt-5.2 disponibles sin
// trámite adicional). El resto de la infraestructura del laboratorio permanece intacta en
// mexicocentral.
//
// Desplegar con (desde la VM Puente, con az cli autenticado):
//   az deployment group create \
//     --resource-group rg-legacy-apps-demo-mxc \
//     --template-file infra/azure/modules/foundry-oracle-migration.bicep \
//     --parameters infra/azure/modules/foundry-oracle-migration.bicepparam

param location = 'southcentralus'
param foundryAccountName = 'fdy-geper-oracle-migration-kt2comvd'
param modelDeploymentName = 'gpt-5-2-oracle-migration'
param modelName = 'gpt-5.2'
param modelVersion = '2025-12-11'
param modelCapacity = 1000
param modelSkuName = 'GlobalStandard'
param foundryProjectName = 'geper-oracle-migration'
param presenterPrincipalId = readEnvironmentVariable('FOUNDRY_PRESENTER_PRINCIPAL_ID', '')
param tags = {
  application: 'GEPER'
  purpose: 'presenter-tool-oracle-to-postgres-schema-conversion'
  partOfLab: 'false'
}
