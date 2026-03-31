[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TemplateFile,

    [Parameter(Mandatory = $true)]
    [string[]]$ParameterFiles,

    [Parameter(Mandatory = $true)]
    [string]$OutputFile
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

$template = Get-BicepTemplateJson -TemplateFile $TemplateFile
$templateParameterNames = @{}
foreach ($parameterProperty in $template.parameters.PSObject.Properties) {
    $templateParameterNames[$parameterProperty.Name] = $true
}

$resolvedParameters = [ordered]@{}
foreach ($parameterFile in $ParameterFiles) {
    if (-not (Test-Path -LiteralPath $parameterFile)) {
        continue
    }

    $parameterDocument = Get-Content -Raw -LiteralPath $parameterFile | ConvertFrom-Json
    if ($null -eq $parameterDocument.parameters) {
        continue
    }

    foreach ($parameterProperty in $parameterDocument.parameters.PSObject.Properties) {
        if ($templateParameterNames.ContainsKey($parameterProperty.Name)) {
            $resolvedParameters[$parameterProperty.Name] = $parameterProperty.Value
        }
    }
}

$outputDirectory = Split-Path -Parent -Path $OutputFile
if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
    New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
}

$outputDocument = [ordered]@{
    '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
    contentVersion = '1.0.0.0'
    parameters = $resolvedParameters
}

$outputDocument | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $OutputFile -Encoding utf8

Write-Host "Created resolved parameter file '$OutputFile' for template '$TemplateFile'."
Write-Host "Included parameters: $((@($resolvedParameters.Keys) -join ', '))"
