<#
.SYNOPSIS
    Script operativo desde la estación de trabajo para desplegar, validar, iniciar, desasignar,
    restablecer datos, abrir túnel SSH o eliminar el laboratorio de GEPER en Azure Mexico Central.
.DESCRIPTION
    Operaciones soportadas (-Action):
    - Validate     : Ejecuta az bicep build, az deployment sub validate y what-if en mexicocentral.
    - Deploy       : Ejecuta el despliegue de Bicep de GEPER en mexicocentral.
    - Start        : Inicia la VM vm-geper-ora.
    - Deallocate   : Desasigna (detiene facturación de cómputo) la VM vm-geper-ora.
    - ResetDataset : Invoca reset-dataset-geper.sh dentro de la VM mediante az vm run-command.
    - Tunnel       : Abre un túnel SSH autenticado local (localhost:8080 -> 127.0.0.1:8080 en la VM).
    - Teardown     : Elimina exclusivamente los recursos de GEPER del grupo de recursos (requiere -ConfirmTeardown).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Validate', 'Deploy', 'Start', 'Deallocate', 'ResetDataset', 'Tunnel', 'Teardown')]
    [string]$Action,

    [string]$SubscriptionId = $env:AZURE_SUBSCRIPTION_ID,
    [string]$Location = "mexicocentral",
    [string]$ResourceGroupName = "rg-legacy-apps-demo-mxc",
    [string]$VmName = "vm-geper-ora",
    [string]$AdminUsername = "geperadmin",
    [string]$SshKeyPath = "",
    [int]$LocalTunnelPort = 8080,
    [string]$PresenterAllowedCidr = "",
    [switch]$ConfirmTeardown
)

$ErrorActionPreference = "Stop"
$infraDir = Split-Path -Parent $PSScriptRoot
$bicepFile = Join-Path $infraDir "main.bicep"
$paramFile = Join-Path $infraDir "main.bicepparam"

if ($SubscriptionId) {
    az account set --subscription $SubscriptionId
    if ($LASTEXITCODE -ne 0) { throw "No se pudo seleccionar la suscripción $SubscriptionId." }
}

switch ($Action) {
    'Validate' {
        Write-Host "==> Compilando Bicep ($bicepFile)..."
        az bicep build --file $bicepFile --stdout | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Error compilando Bicep." }

        Write-Host "==> Ejecutando validación ARM..."
        az deployment sub validate `
            --location $Location `
            --name "validate-geper-mxc" `
            --parameters $paramFile `
            --parameters existingResourceGroupName=$ResourceGroupName presenterAllowedCidr=$PresenterAllowedCidr `
            --query "{provisioningState:properties.provisioningState, error:error}" -o json
        if ($LASTEXITCODE -ne 0) { throw "Error en validación ARM." }

        Write-Host "==> Ejecutando what-if..."
        az deployment sub what-if `
            --location $Location `
            --name "whatif-geper-mxc" `
            --parameters $paramFile `
            --parameters existingResourceGroupName=$ResourceGroupName presenterAllowedCidr=$PresenterAllowedCidr
    }
    'Deploy' {
        if ([string]::IsNullOrEmpty($env:GEPER_VM_SSH_PUBLIC_KEY) -and [string]::IsNullOrEmpty($env:GEPER_VM_ADMIN_PASSWORD)) {
            throw "Defina GEPER_VM_SSH_PUBLIC_KEY o GEPER_VM_ADMIN_PASSWORD antes de ejecutar Deploy."
        }
        Write-Host "==> Desplegando recursos de GEPER en $Location (grupo existente $ResourceGroupName)..."
        az deployment sub create `
            --location $Location `
            --name "deploy-geper-mxc" `
            --parameters $paramFile `
            --parameters existingResourceGroupName=$ResourceGroupName presenterAllowedCidr=$PresenterAllowedCidr `
            --query "{provisioningState:properties.provisioningState, outputs:properties.outputs}" -o json
    }
    'Start' {
        Write-Host "==> Iniciando VM $VmName en $ResourceGroupName..."
        az vm start --resource-group $ResourceGroupName --name $VmName
    }
    'Deallocate' {
        Write-Host "==> Desasignando VM $VmName en $ResourceGroupName (detiene cargos de cómputo)..."
        az vm deallocate --resource-group $ResourceGroupName --name $VmName
    }
    'ResetDataset' {
        Write-Host "==> Restableciendo dataset sintético de GEPER en $VmName..."
        az vm run-command invoke `
            --resource-group $ResourceGroupName `
            --name $VmName `
            --command-id RunShellScript `
            --scripts "bash /var/opt/geper/stage/scripts/reset-dataset-geper.sh --mode full" `
            --query "value[0].message" -o tsv
    }
    'Tunnel' {
        $pip = az vm show -d --resource-group $ResourceGroupName --name $VmName --query publicIps -o tsv
        if ([string]::IsNullOrWhiteSpace($pip)) {
            throw "No se encontró IP pública asociada a $VmName."
        }
        Write-Host "==> Abriendo túnel SSH hacia ${AdminUsername}@${pip} (http://localhost:${LocalTunnelPort} -> 127.0.0.1:8080)..."
        if ($SshKeyPath) {
            & ssh -i $SshKeyPath -N -L "${LocalTunnelPort}:127.0.0.1:8080" "${AdminUsername}@${pip}"
        } else {
            & ssh -N -L "${LocalTunnelPort}:127.0.0.1:8080" "${AdminUsername}@${pip}"
        }
    }
    'Teardown' {
        if (-not $ConfirmTeardown) {
            throw "Para eliminar los recursos de GEPER debe especificar explícitamente -ConfirmTeardown."
        }
        Write-Host "==> Eliminando VM, NIC, IP pública, NSG y discos de GEPER en $ResourceGroupName..."
        az vm delete --resource-group $ResourceGroupName --name $VmName --yes
        az network nic delete --resource-group $ResourceGroupName --name "nic-$VmName"
        az network public-ip delete --resource-group $ResourceGroupName --name "pip-$VmName"
        az network nsg delete --resource-group $ResourceGroupName --name "nsg-$VmName"
        az disk delete --resource-group $ResourceGroupName --name "osdisk-$VmName" --yes
        az disk delete --resource-group $ResourceGroupName --name "disk-$VmName-oradata" --yes
    }
}
