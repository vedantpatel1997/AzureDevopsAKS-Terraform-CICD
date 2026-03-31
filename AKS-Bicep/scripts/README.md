# Scripts Folder

This folder contains helper scripts used by the Bicep learning workflow.

## Current scripts

- `Resolve-AksBicepNames.ps1`
- `Get-AksBicepDeploymentConfig.ps1`

## What it does

`Resolve-AksBicepNames.ps1` calculates the same derived names used by the Bicep templates, such as:

- resource group name
- AKS cluster name
- node resource group name
- subnet names
- Entra admin group unique name

`Get-AksBicepDeploymentConfig.ps1` reads the effective deployment settings from:

- `shared.parameters.json`
- the selected environment parameter file
- the Bicep template defaults as fallback

It is used so the pipelines follow the Bicep configuration instead of duplicating values in YAML.

The precedence is:

1. environment parameter file
2. shared parameter file
3. `.bicep` template defaults

So if a value exists in a parameter file, changing only the template default will not affect the pipeline run.

## Why the pipelines use it

The destroy pipeline needs a reliable way to know what to inspect and delete before it starts removing resources.

Instead of hard-coding names and config values in multiple places, the pipelines call these scripts and write the results into the review bundle.

That makes it easier to:

- review exactly what destroy will target
- understand how naming is derived
- keep the review and destroy logic aligned
- keep the YAML aligned with the Bicep source of truth

## Example local use

```powershell
powershell -NoLogo -NoProfile -File AKS-Bicep/scripts/Resolve-AksBicepNames.ps1 -Environment dev -Location westus2 -OrganizationName vp
```

```powershell
powershell -NoLogo -NoProfile -File AKS-Bicep/scripts/Get-AksBicepDeploymentConfig.ps1 -BootstrapTemplateFile AKS-Bicep/Bicep-manifests/bootstrap-admin-group.bicep -MainTemplateFile AKS-Bicep/Bicep-manifests/main.bicep -ParameterFiles AKS-Bicep/Bicep-manifests/shared.parameters.json,AKS-Bicep/Bicep-manifests/environments/dev.parameters.json
```
