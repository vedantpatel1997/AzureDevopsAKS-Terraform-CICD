# Bicep Manifests Deep Dive

This folder contains the Bicep files that define the AKS platform.

If you are comparing Terraform and Bicep side by side, this is the folder to study next to:

- `AKS-Terraform/Terraform-manifests/`

## Files in this folder

- `main.bicep`
  Subscription-scope AKS platform deployment. Creates the resource group if needed, then deploys the AKS Azure resources.
- `bootstrap-admin-group.bicep`
  Subscription-scope bootstrap deployment. Creates the resource group if needed, then deploys the Entra admin group module.
- `aks-platform.bicep`
  Creates the AKS Azure resources and expects an existing Entra admin group object ID.
- `entra-admin-group.bicep`
  Creates the Microsoft Entra admin group and adds the configured user to it.
- `bicepconfig.json`
  Enables the Microsoft Graph Bicep extension so the template can manage Entra group resources.
- `shared.parameters.json`
  Shared values used by both the bootstrap and platform deployments.
- `environments/`
  Small environment parameter files for `dev`, `qa`, and `prod`.

## Why there are multiple Bicep files

This split teaches an important Azure deployment concept:

- resource group creation happens at subscription scope
- AKS, network, Log Analytics, and most platform resources deploy at resource group scope
- AKS needs a real existing Entra group object ID for `aadProfile.adminGroupObjectIDs`

So the design is intentionally two-phase:

1. `bootstrap-admin-group.bicep` creates the resource group and Entra admin group.
2. `main.bicep` creates the AKS Azure resources using the real Entra group object ID from step 1.

That is the Bicep equivalent of how the Terraform project creates both the resource group and the resources inside it.

## Terraform-to-Bicep mapping

| Terraform file | Bicep equivalent |
| --- | --- |
| `01-resource-group.tf` | `bootstrap-admin-group.bicep` and `main.bicep` resource group resource |
| `02-log-analytics-workspace.tf` | `aks-platform.bicep` Log Analytics resource |
| `02-virtual-network.tf` | `aks-platform.bicep` VNet and subnet resources |
| `03-entra-admin-group.tf` | `entra-admin-group.bicep` Microsoft Graph group resource and existing user reference |
| `04-aks-cluster.tf` | `aks-platform.bicep` managed cluster resource |
| `05-aks-linux-user-node-pool.tf` | `aks-platform.bicep` Linux `agentPools` child resource |
| `06-aks-windows-user-node-pool.tf` | `aks-platform.bicep` Windows `agentPools` child resource |
| `locals.tf` | `var` declarations in `main.bicep` and `aks-platform.bicep` |
| `outputs.tf` | `output` declarations in both Bicep files |

## Naming logic

The naming style intentionally mirrors the Terraform project.

Examples for `dev` in `westus2` with the current shared parameter file value `organizationName = bicep`:

- resource group: `rg-bicep-aks-dev-westus2`
- AKS cluster: `aks-bicep-dev-westus2`
- node resource group: `rg-bicep-aks-dev-westus2-nodes`
- Log Analytics workspace: `log-bicep-aks-dev-westus2`
- virtual network: `vnet-bicep-aks-dev-westus2`
- system subnet: `snet-bicep-aks-dev-westus2-system`
- Entra admin group: `grp-aksadmin-aks-bicep-dev-westus2`

## Parameters that matter most

These are the first parameters worth understanding:

- `environment`
  Changes naming and environment tags.
- `location`
  Azure region for the deployment.
- `organizationName`
  Prefix used in resource names.
- `kubernetesVersion`
  Pinned AKS version.
- `sshPublicKeyData`
  SSH key content passed in from the pipeline.
- `createLinuxUserNodePool`
  Matches the Terraform option for the extra Linux node pool.
- `createWindowsUserNodePool`
  Matches the Terraform option for the extra Windows node pool.

## Source of truth for configuration

For the Bicep workflow in this repo:

- the parameter files are the source of truth for shared deployment values
- the Azure DevOps pipelines read those effective values at runtime
- the pipelines do not own `organizationName`, `location`, or `kubernetesVersion`
- parameter files override the fallback defaults inside the `.bicep` templates

That means if you change `shared.parameters.json` or an environment parameter file, the pipeline follows that change without needing a YAML edit.

In the current repo state:

- the `.bicep` template fallback for `organizationName` is `vp`
- the active shared parameter file sets `organizationName` to `bicep`
- pipeline runs therefore use `bicep` unless you change the parameter files

## Why the SSH key is data instead of a file path

Terraform uses `file(var.ssh_public_key)` inside the repo.

Bicep is different here. The template does not read a repo file path during deployment. Instead:

1. Azure DevOps downloads the secure file.
2. The pipeline reads the public key content.
3. The pipeline passes that text to `sshPublicKeyData`.

That difference is normal and useful to learn.

## Why `bicepconfig.json` matters

This template creates a Microsoft Entra security group and adds a user to it.

That is not a normal Azure Resource Manager type. To make that possible, this folder includes:

- `bicepconfig.json`
- `extension microsoftGraphV1` in `aks-platform.bicep`

Without that configuration, the Entra group resource definitions would not compile.

## Why the bootstrap step exists

AKS validates `aadProfile.adminGroupObjectIDs` as real GUID values during deployment.

That means the AKS deployment cannot safely depend on a brand-new Entra group object ID created in the same validation pass.

So the repo uses:

1. `bootstrap-admin-group.bicep`
2. `main.bicep`

This is not accidental complexity. It is the working pattern that makes the deployment reliable and also teaches an important Terraform vs Bicep difference.

## Outputs

The template outputs values that are useful for learning and troubleshooting:

- resource group name and ID
- cluster name and ID
- virtual network name and ID
- configured Kubernetes version
- Log Analytics workspace name and ID
- Entra admin group display name, unique name, and object ID
- subnet IDs
- optional user node pool IDs

## Manual study tip

A very good way to compare Terraform vs Bicep in this repo is:

1. Open `AKS-Terraform/Terraform-manifests/locals.tf`.
2. Open `AKS-Bicep/Bicep-manifests/aks-platform.bicep`.
3. Compare the naming variables first.
4. Then compare resource by resource in the mapping table above.
