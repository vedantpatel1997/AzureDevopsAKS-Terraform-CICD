[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BootstrapTemplateFile,

    [Parameter(Mandatory = $true)]
    [string]$MainTemplateFile,

    [Parameter(Mandatory = $true)]
    [string[]]$ParameterFiles
)

$ErrorActionPreference = 'Stop'

function Get-BicepTemplateJson {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TemplateFile
    )

    $templateJson = az bicep build --file $TemplateFile --stdout
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to build Bicep template '$TemplateFile'."
    }

    return $templateJson | ConvertFrom-Json
}

function Get-ParameterFileValue {
    param(
        [Parameter()]
        [object]$ParameterDocument,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $ParameterDocument -or $null -eq $ParameterDocument.parameters) {
        return $null
    }

    $parameterProperty = $ParameterDocument.parameters.PSObject.Properties[$Name]
    if ($null -eq $parameterProperty) {
        return $null
    }

    $valueProperty = $parameterProperty.Value.PSObject.Properties['value']
    if ($null -eq $valueProperty) {
        return $null
    }

    return $valueProperty.Value
}

function Get-TemplateDefaultValue {
    param(
        [Parameter()]
        [object]$TemplateDocument,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $TemplateDocument -or $null -eq $TemplateDocument.parameters) {
        return $null
    }

    $parameterProperty = $TemplateDocument.parameters.PSObject.Properties[$Name]
    if ($null -eq $parameterProperty) {
        return $null
    }

    $defaultProperty = $parameterProperty.Value.PSObject.Properties['defaultValue']
    if ($null -eq $defaultProperty) {
        return $null
    }

    return $defaultProperty.Value
}

function Resolve-EffectiveValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [object[]]$TemplateDocuments,

        [Parameter()]
        [object[]]$ParameterDocuments
    )

    for ($index = $ParameterDocuments.Count - 1; $index -ge 0; $index--) {
        $parameterDocument = $ParameterDocuments[$index]
        $parameterValue = Get-ParameterFileValue -ParameterDocument $parameterDocument -Name $Name
        if ($null -ne $parameterValue) {
            return $parameterValue
        }
    }

    foreach ($templateDocument in $TemplateDocuments) {
        $defaultValue = Get-TemplateDefaultValue -TemplateDocument $templateDocument -Name $Name
        if ($null -ne $defaultValue) {
            return $defaultValue
        }
    }

    return $null
}

$bootstrapTemplate = Get-BicepTemplateJson -TemplateFile $BootstrapTemplateFile
$mainTemplate = Get-BicepTemplateJson -TemplateFile $MainTemplateFile
$parameterDocuments = foreach ($parameterFile in $ParameterFiles) {
    if (Test-Path -LiteralPath $parameterFile) {
        Get-Content -Raw -LiteralPath $parameterFile | ConvertFrom-Json
    }
}

$result = [ordered]@{
    environment               = Resolve-EffectiveValue -Name 'environment' -TemplateDocuments @($mainTemplate, $bootstrapTemplate) -ParameterDocuments $parameterDocuments
    location                  = Resolve-EffectiveValue -Name 'location' -TemplateDocuments @($mainTemplate, $bootstrapTemplate) -ParameterDocuments $parameterDocuments
    organizationName          = Resolve-EffectiveValue -Name 'organizationName' -TemplateDocuments @($mainTemplate, $bootstrapTemplate) -ParameterDocuments $parameterDocuments
    kubernetesVersion         = Resolve-EffectiveValue -Name 'kubernetesVersion' -TemplateDocuments @($mainTemplate) -ParameterDocuments $parameterDocuments
    aksAdminUserPrincipalName = Resolve-EffectiveValue -Name 'aksAdminUserPrincipalName' -TemplateDocuments @($bootstrapTemplate) -ParameterDocuments $parameterDocuments
}

$missingValues = @($result.GetEnumerator() | Where-Object { $null -eq $_.Value } | ForEach-Object { $_.Key })
if ($missingValues.Count -gt 0) {
    throw "Unable to resolve the following Bicep configuration values from the templates and parameter files: $($missingValues -join ', ')"
}

$result | ConvertTo-Json -Depth 20
