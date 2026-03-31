# AKS Bicep Project Guide

This folder contains a Bicep version of the AKS platform that already exists in `AKS-Terraform/`.

The goal is not just to deploy AKS. The goal is to help you learn how the same infrastructure looks and behaves when written in Bicep instead of Terraform.

## What this Bicep version creates

The template is designed to mirror the Terraform example as closely as possible.

It creates:

- an Azure resource group for the AKS platform
- a Log Analytics workspace
- a virtual network
- a system node pool subnet
- an optional Linux user node pool subnet
- an optional Windows user node pool subnet
- an AKS cluster with Azure CNI networking
- a Microsoft Entra admin group for AKS admins
- membership of one Entra user in that admin group
- an optional Linux user node pool
- an optional Windows user node pool

The Bicep templates still keep Terraform-like fallback defaults in the `.bicep` files, but the active pipeline values come from the parameter files.

Current pipeline-backed defaults in this repo:

- location: `westus2`
- organization name: `bicep`
- environments: `dev`, `qa`, `prod`
- Kubernetes version: `1.34.3`
- Linux and Windows user pools disabled by default

Important:

- the `.bicep` files still use `vp` as their fallback default so you can compare the naming logic with Terraform
- pipeline runs use `Bicep-manifests/shared.parameters.json` first, so changing that file updates the deployed naming automatically
- if the Terraform version is already deployed with the same naming inputs, the Bicep version will target the same resource names

## Folder structure

- `Bicep-manifests/`
  Main Bicep files, Bicep config, and environment parameter files.
- `scripts/`
  Helper script used by the destroy and review pipeline stages.
- `Bicep-provision-aks-cluster-pipeline.yml`
  Azure DevOps create pipeline.
- `Bicep-destroy-aks-cluster-pipeline.yml`
  Azure DevOps destroy pipeline.

## The big Terraform vs Bicep difference

For create and update:

- Terraform uses `plan` and `apply`.
- Bicep uses `what-if` and `deployment create`.

For destroy:

- Terraform has a first-class destroy flow because it has state.
- Bicep does not have a native `destroy` command for everything in this example.

That is why the destroy pipeline here is explicit and educational:

1. It resolves the exact resource names for the chosen environment.
2. It inspects the resource group and publishes a review bundle.
3. After approval, it deletes the Azure resource group.
4. It separately deletes the Microsoft Entra admin group by `uniqueName`.

This is the most important practical lesson in the whole comparison.

## Active pipeline files

Use these two YAML files as the active pipelines for the Bicep project:

- `Bicep-provision-aks-cluster-pipeline.yml`
- `Bicep-destroy-aks-cluster-pipeline.yml`

Main infrastructure code:

- `Bicep-manifests/`

## How the Bicep pipelines are designed

The Bicep pipelines intentionally follow the same approval style used by the Terraform pipelines.

They reuse the same Azure DevOps environments:

- `dev`
- `qa`
- `prod`

That means:

- the create pipeline pauses after the review artifact is produced
- the destroy pipeline also pauses after its review artifact is produced
- approvals happen after review, not before review

Configuration source of truth:

- the pipelines no longer hard-code `organizationName`, `location`, `kubernetesVersion`, or `aksAdminUserPrincipalName`
- shared values come from `Bicep-manifests/shared.parameters.json`
- environment-specific values come from `Bicep-manifests/environments/<environment>.parameters.json`
- parameter files override `.bicep` defaults
- if you change those files, the pipeline will use the new values automatically

## Pipeline behavior

### Create pipeline

File:

- `Bicep-provision-aks-cluster-pipeline.yml`

Flow:

1. Validate the Bicep files.
2. Generate a filtered bootstrap parameter file for the resource group and Entra admin group template.
3. Generate a filtered platform parameter file for the AKS template.
4. Generate a bootstrap `what-if` for the resource group and Entra admin group.
5. Generate a platform `what-if` for the AKS resources by using a temporary preview GUID for the admin group object ID.
6. Publish the review JSON files and resolved resource names as artifacts.
7. Wait for approval on `dev`, `qa`, or `prod`.
8. Create or update the Entra admin group through the bootstrap deployment.
9. Deploy the AKS platform using the real admin group object ID.
10. Publish deployment outputs.

### Destroy pipeline

File:

- `Bicep-destroy-aks-cluster-pipeline.yml`

Flow:

1. Validate the Bicep files.
2. Resolve the resource names for each selected environment.
3. Inspect the Azure resource group and the Entra group.
4. Publish a destroy review bundle.
5. Wait for approval on `dev`, `qa`, or `prod`.
6. Delete the Azure resource group.
7. Delete the Entra group by `uniqueName`.

## Names this project expects

Only the Azure DevOps object names below are fixed in YAML.

Infrastructure settings such as `organizationName`, `location`, and `kubernetesVersion` are not hard-coded in the pipeline anymore.
They are read from the shared and environment parameter files at runtime.

### Azure DevOps names

- Environment 1: `dev`
- Environment 2: `qa`
- Environment 3: `prod`
- Secure file: `aks-terraform-devops-ssh-key-ubuntu.pub`
- Service connection: `terraform-aks-azurerm-svc-con`

Why the names look Terraform-specific:

- the Bicep example intentionally reuses the same DevOps objects so you can test without creating a second service connection and a second secure file

## Permissions you need

If the Terraform version already works in your Azure DevOps project, you are probably close to ready for the Bicep version too.

The service connection still needs to do two kinds of work:

- Azure Resource Manager work for resource group, network, Log Analytics, and AKS resources
- Microsoft Graph work for the Entra admin group and group membership

In practice, make sure the identity behind the service connection can:

- create and delete the target Azure resources
- create and delete Microsoft Entra groups
- read the target Entra user by user principal name

## Recommended one-time Azure DevOps setup order

If your Terraform setup already exists, most of this is already done.

1. Confirm the repo contains the `AKS-Bicep` folder.
2. Confirm the service connection `terraform-aks-azurerm-svc-con` exists.
3. Confirm the secure file `aks-terraform-devops-ssh-key-ubuntu.pub` exists.
4. Confirm the reusable environments `dev`, `qa`, and `prod` exist.
5. Confirm those environments have approval checks.
6. Create the Bicep create pipeline.
7. Create the Bicep destroy pipeline.
8. Run `dev` first.
9. Use `qa` only after `dev` works.
10. Use `prod` only after both `dev` and `qa` are understood.

## How to create the pipelines

### Create pipeline

1. Open `Pipelines`.
2. Select `New pipeline`.
3. Choose the repo.
4. Select `Existing Azure Pipelines YAML file`.
5. Choose `AKS-Bicep/Bicep-provision-aks-cluster-pipeline.yml`.
6. Save it with a clear name such as `AKS Bicep Provision`.

### Destroy pipeline

1. Open `Pipelines`.
2. Select `New pipeline`.
3. Choose the repo.
4. Select `Existing Azure Pipelines YAML file`.
5. Choose `AKS-Bicep/Bicep-destroy-aks-cluster-pipeline.yml`.
6. Save it with a clear name such as `AKS Bicep Destroy`.

## What to review before approval

### For create runs

Open the review artifact for the environment:

- `dev-what-if`
- `qa-what-if`
- `prod-what-if`

Then review:

- `effective-config.json`
- `resolved-values.json`
- `bootstrap.resolved.parameters.json`
- `platform.resolved.parameters.json`
- `graph-group.json`
- `<environment>-review.txt`
- `<environment>-bootstrap-what-if.json`
- `<environment>-platform-what-if.json`

Important:

- Microsoft Graph extensible resources have limited `what-if` support, so the bootstrap review may not fully enumerate the Entra group change
- `graph-group.json` in the create review bundle is expected to show `preview-only` during `what-if`
- the platform `what-if` still gives you the important AKS, network, and Log Analytics preview

### For destroy runs

Open the destroy review artifact for the environment:

- `dev-destroy-review`
- `qa-destroy-review`
- `prod-destroy-review`

Then review:

- `effective-config.json`
- `resolved-values.json`
- `resource-group-resources.txt`
- `graph-group.json`
- `<environment>-destroy-review.txt`

## Local testing commands

You can test locally before using Azure DevOps.

### Validate

```powershell
az login
az bicep upgrade
az bicep build --file AKS-Bicep/Bicep-manifests/bootstrap-admin-group.bicep
az bicep restore --file AKS-Bicep/Bicep-manifests/main.bicep
az bicep build --file AKS-Bicep/Bicep-manifests/main.bicep
```

### Bootstrap what-if for dev

```powershell
$bootstrapParams = Join-Path $env:TEMP 'aks-bicep-bootstrap.parameters.json'
powershell -NoLogo -NoProfile -File AKS-Bicep/scripts/New-AksBicepResolvedParameterFile.ps1 `
  -TemplateFile AKS-Bicep/Bicep-manifests/bootstrap-admin-group.bicep `
  -ParameterFiles AKS-Bicep/Bicep-manifests/shared.parameters.json,AKS-Bicep/Bicep-manifests/environments/dev.parameters.json `
  -OutputFile $bootstrapParams

az deployment sub what-if `
  --name aks-bicep-dev-bootstrap-local `
  --location westus2 `
  --template-file AKS-Bicep/Bicep-manifests/bootstrap-admin-group.bicep `
  --parameters "@$bootstrapParams"
```

### Platform what-if for dev

```powershell
$sshKey = (Get-Content -Raw AKS-Terraform/aks-prod-sshkeys-terraform/aksprodsshkey.pub).Trim()
$previewGroupId = [guid]::NewGuid().Guid
$platformParams = Join-Path $env:TEMP 'aks-bicep-platform.parameters.json'
powershell -NoLogo -NoProfile -File AKS-Bicep/scripts/New-AksBicepResolvedParameterFile.ps1 `
  -TemplateFile AKS-Bicep/Bicep-manifests/main.bicep `
  -ParameterFiles AKS-Bicep/Bicep-manifests/shared.parameters.json,AKS-Bicep/Bicep-manifests/environments/dev.parameters.json `
  -OutputFile $platformParams

az deployment sub what-if `
  --name aks-bicep-dev-platform-local `
  --location westus2 `
  --template-file AKS-Bicep/Bicep-manifests/main.bicep `
  --parameters "@$platformParams" `
  --parameters aksAdminGroupObjectId=$previewGroupId `
               aksAdminGroupDisplayName=grp-aksadmin-aks-bicep-dev-westus2 `
               aksAdminGroupUniqueName=grp-aksadmin-aks-bicep-dev-westus2 `
               sshPublicKeyData="$sshKey"
```

### Create dev

First bootstrap the Entra group and capture its outputs:

```powershell
$bootstrapParams = Join-Path $env:TEMP 'aks-bicep-bootstrap.parameters.json'
powershell -NoLogo -NoProfile -File AKS-Bicep/scripts/New-AksBicepResolvedParameterFile.ps1 `
  -TemplateFile AKS-Bicep/Bicep-manifests/bootstrap-admin-group.bicep `
  -ParameterFiles AKS-Bicep/Bicep-manifests/shared.parameters.json,AKS-Bicep/Bicep-manifests/environments/dev.parameters.json `
  -OutputFile $bootstrapParams

$bootstrap = az deployment sub create `
  --name aks-bicep-dev-bootstrap-local `
  --location westus2 `
  --template-file AKS-Bicep/Bicep-manifests/bootstrap-admin-group.bicep `
  --parameters "@$bootstrapParams" `
  --query properties.outputs `
  --output json | ConvertFrom-Json
```

Then deploy the AKS platform with the real group object ID:

```powershell
$sshKey = (Get-Content -Raw AKS-Terraform/aks-prod-sshkeys-terraform/aksprodsshkey.pub).Trim()
$platformParams = Join-Path $env:TEMP 'aks-bicep-platform.parameters.json'
powershell -NoLogo -NoProfile -File AKS-Bicep/scripts/New-AksBicepResolvedParameterFile.ps1 `
  -TemplateFile AKS-Bicep/Bicep-manifests/main.bicep `
  -ParameterFiles AKS-Bicep/Bicep-manifests/shared.parameters.json,AKS-Bicep/Bicep-manifests/environments/dev.parameters.json `
  -OutputFile $platformParams

az deployment sub create `
  --name aks-bicep-dev-platform-local `
  --location westus2 `
  --template-file AKS-Bicep/Bicep-manifests/main.bicep `
  --parameters "@$platformParams" `
  --parameters aksAdminGroupObjectId=$bootstrap.aksAdminGroupObjectId.value `
               aksAdminGroupDisplayName=$bootstrap.aksAdminGroupDisplayName.value `
               aksAdminGroupUniqueName=$bootstrap.aksAdminGroupUniqueName.value `
               sshPublicKeyData="$sshKey"
```

### Destroy dev

```powershell
az group delete --name rg-bicep-aks-dev-westus2 --yes
az rest --method delete --url "https://graph.microsoft.com/v1.0/groups(uniqueName='grp-aksadmin-aks-bicep-dev-westus2')"
```

## Common beginner questions

### Why is the Bicep create pipeline using what-if instead of plan?

Because `what-if` is the closest ARM/Bicep concept to a Terraform plan.

### Why is the Bicep destroy pipeline not using a single Bicep destroy command?

Because ARM/Bicep does not manage destruction in the same state-driven way Terraform does.

### Why does the Bicep project still use the Terraform secure file name?

To keep your first comparison easy. You can rename it later if you want, but reusing the same secure file reduces setup work.

### Why is there a placeholder Windows password?

Because the Terraform sample already uses one, and this Bicep version is meant to be easy to test side by side.

For any real usage, override it.

### Can I keep the Terraform and Bicep versions deployed at the same time?

Not with the same naming inputs.

Both versions default to the same names for `dev`, `qa`, and `prod`, so they will target the same Azure resource names.

If you want both versions to exist side by side, change at least one of these:

- `organizationName`
- `environment`

### If I change `organizationName` in Bicep, do I need to edit the pipeline too?

No.

The pipeline now resolves the effective values from:

1. `Bicep-manifests/shared.parameters.json`
2. the selected environment parameter file
3. the Bicep defaults only if a value is not supplied in those files

So if you change `organizationName` in `shared.parameters.json`, the pipeline will pick that up automatically.

Important:

- if `organizationName` is present in a parameter file, changing only the `.bicep` default will not change the pipeline behavior
- that is intentional because the same shared parameter file feeds both `bootstrap-admin-group.bicep` and `main.bicep`, which keeps them aligned
- if you want template defaults to drive the pipeline instead, remove that parameter from the parameter files and keep the defaults aligned in both templates

## Safe operating advice

- test only `dev` first
- review artifacts before every approval
- do not run destroy casually
- remember that destroy deletes Azure resources and then separately deletes the Entra admin group
- keep `prod` approvals limited to a small trusted group
