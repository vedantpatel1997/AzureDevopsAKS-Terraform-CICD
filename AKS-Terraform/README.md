# AKS Terraform Project Guide

This folder contains the Terraform code and Azure DevOps YAML pipelines used to provision and destroy AKS environments.

This guide is written for beginners and matches the current pipeline design in this repo.

## Current design at a glance

This project now uses three reusable Azure DevOps Environments:

- `dev`
- `qa`
- `prod`

Those same three environment objects are reused by:

- the provision pipeline when it applies Terraform changes
- the destroy pipeline when it applies Terraform destroy plans

Approvals are designed to happen after the Terraform plan stage, not before it. That lets approvers review the generated plan artifact before deciding.

## Active pipeline files

Use these two YAML files as the active pipelines for this Terraform project:

- `Terraform-provision-aks-cluster-pipeline.yml`
- `Terraform-destroy-aks-cluster-pipeline.yml`

Main Terraform code:

- `Terraform-manifests/`

Other useful folders:

- `kube-manifests/`
- `aks-prod-sshkeys-terraform/`

## How the pipelines work now

### Provision pipeline

File:

- `Terraform-provision-aks-cluster-pipeline.yml`

Flow:

1. Validate Terraform.
2. Create the dev plan.
3. Create the QA plan.
4. Create the prod plan.
5. Wait for approval on the reusable `dev` environment.
6. Apply the approved dev plan.
7. Wait for approval on the reusable `qa` environment.
8. Apply the approved QA plan.
9. Wait for approval on the reusable `prod` environment.
10. Apply the approved prod plan.

Why this is a good practice:

- approvers review the Terraform plan before apply starts
- `dev`, `qa`, and `prod` can run in parallel after validation
- the exact reviewed plan file is what gets applied

### Destroy pipeline

File:

- `Terraform-destroy-aks-cluster-pipeline.yml`

Flow:

1. Choose `dev`, `qa`, or `prod` when you start the run.
2. Validate Terraform.
3. Create a destroy plan for the selected environment.
4. Wait for approval on the same reusable environment object.
5. Apply the reviewed destroy plan.

Why this is a good practice:

- destroy approval also happens after the plan is visible
- the approver can review the `.txt` plan summary before approving
- the pipeline applies the exact reviewed destroy plan

## Names this project expects

These names are currently hard-coded in the YAML files. If you change them in Azure DevOps or Azure, update the YAML too.

### Azure DevOps names

- Environment 1: `dev`
- Environment 2: `qa`
- Environment 3: `prod`
- Secure file: `aks-terraform-devops-ssh-key-ubuntu.pub`
- Service connection: `terraform-aks-azurerm-svc-con`

### Terraform backend names

- Resource group: `TerraformStorageAccount`
- Storage account: `strgterraformvp`
- Blob container: `tfstatefiles`

### Terraform state files

- `aks-dev.tfstate`
- `aks-qa.tfstate`
- `aks-prod.tfstate`

## Before you start

Make sure you have:

1. An Azure DevOps project.
2. This repository connected to Azure DevOps Repos or GitHub.
3. Permission to create pipelines, environments, secure files, and service connections.
4. Permission in Azure to create and delete AKS-related resources.
5. The Terraform backend storage already created.
6. The SSH public key file that will be uploaded as a Secure File.
7. The Terraform Azure DevOps extension installed if your organization does not already have the Terraform tasks.

Quick check:

- If Azure DevOps does not recognize `TerraformInstaller@1` or `TerraformTask@5`, install the Terraform extension first.

## Recommended one-time setup order

Set up the project in this order:

1. Confirm your repo and branch.
2. Install the Terraform extension if needed.
3. Create the Azure Resource Manager service connection.
4. Confirm the service connection has Azure permissions.
5. Upload the SSH public key as a Secure File.
6. Create the reusable environments `dev`, `qa`, and `prod`.
7. Add approval checks to `dev`, `qa`, and `prod`.
8. Create the provision pipeline.
9. Create the destroy pipeline.
10. Run a dev test first.
11. Use QA after dev is working.
12. Use prod only after dev and QA are working and approvals are confirmed.

## Step-by-step Azure DevOps setup

### Step 1: Confirm the repository and branch

Before creating pipelines:

1. Confirm the repo contains the `AKS-Terraform` folder.
2. Confirm the branch used for automatic deployments is `main`.
3. Confirm both YAML files exist in that branch.

Why this matters:

- the provision pipeline uses `trigger: main`
- if your working branch strategy is different, update the YAML trigger before relying on auto-runs

### Step 2: Install the Terraform Azure DevOps extension if needed

This repo uses:

- `TerraformInstaller@1`
- `TerraformTask@5`

If Azure DevOps does not recognize those tasks:

1. Open Azure DevOps Marketplace.
2. Find the Terraform extension used by your organization for Azure Pipelines.
3. Install it into your Azure DevOps organization.
4. Return to your project and reopen the pipeline editor.

### Step 3: Create the Azure Resource Manager service connection

The YAML expects this exact service connection name:

- `terraform-aks-azurerm-svc-con`

Create it:

1. Open `Project settings`.
2. Open `Service connections`.
3. Select `New service connection`.
4. Choose `Azure Resource Manager`.
5. Follow the Azure sign-in flow.
6. Save it as `terraform-aks-azurerm-svc-con`.

Recommended approach:

- use workload identity federation if your Azure DevOps organization supports it

### Step 4: Confirm the service connection has Azure permissions

The service connection must be able to:

- read and write the Terraform backend
- create and update AKS resources
- delete AKS resources for destroy runs

Check access to:

- the target subscription or resource group
- the resource group `TerraformStorageAccount`
- the storage account `strgterraformvp`
- the blob container `tfstatefiles`

If this is missing, common failures are:

- `terraform init` backend errors
- `terraform plan` access errors
- `terraform apply` authorization errors

### Step 5: Upload the SSH public key as a Secure File

Both pipelines expect this exact secure file name:

- `aks-terraform-devops-ssh-key-ubuntu.pub`

Upload it:

1. Open `Pipelines`.
2. Open `Library`.
3. Open `Secure files`.
4. Select `+ Secure file`.
5. Upload the public key file.
6. Confirm the file name matches exactly.
7. Authorize the pipelines to use it.

Important:

- upload the public key, not the private key
- if the name does not match the YAML, the run will fail

### Step 6: Create the reusable Azure DevOps Environments

Create these three environments:

- `dev`
- `qa`
- `prod`

How:

1. Open `Pipelines`.
2. Open `Environments`.
3. Select `New environment`.
4. Create `dev`.
5. Create `qa`.
6. Create `prod`.

How they are reused:

- provision apply for dev uses `dev`
- destroy apply for dev uses `dev`
- provision apply for qa uses `qa`
- destroy apply for qa uses `qa`
- provision apply for prod uses `prod`
- destroy apply for prod uses `prod`

### Step 7: Add approval checks to the reusable environments

This is the key part of the approval model.

Add approval checks to:

- `dev`
- `qa`
- `prod`

How:

1. Open `Pipelines`.
2. Open `Environments`.
3. Select `dev`.
4. Open `Approvals and checks`.
5. Add an `Approval` check.
6. Choose the approvers or approval group.
7. Set the timeout to `120 minutes`.
8. Save the check.
9. Repeat the same steps for `qa`.
10. Repeat the same steps for `prod`.

What this means in practice:

- dev apply pauses after the dev plan is created
- qa apply pauses after the qa plan is created
- prod apply pauses after the prod plan is created
- dev, qa, and prod can progress independently after validation
- destroy also pauses after the destroy plan is created
- the same environment approval policy is reused for both pipeline types

### Step 8: Create the provision pipeline

1. Open `Pipelines`.
2. Select `New pipeline`.
3. Choose the repository.
4. Choose `Existing Azure Pipelines YAML file`.
5. Select `AKS-Terraform/Terraform-provision-aks-cluster-pipeline.yml`.
6. Review the YAML preview.
7. Save it with a clear name such as `AKS Terraform Provision`.

What happens after creation:

- pushes to `main` can trigger it automatically
- after Terraform validation, the dev, qa, and prod plan stages can run in parallel
- each environment then waits on its own approval before apply

### Step 9: Create the destroy pipeline

1. Open `Pipelines`.
2. Select `New pipeline`.
3. Choose the repository.
4. Choose `Existing Azure Pipelines YAML file`.
5. Select `AKS-Terraform/Terraform-destroy-aks-cluster-pipeline.yml`.
6. Review the YAML preview.
7. Save it with a clear name such as `AKS Terraform Destroy`.

What happens after creation:

- it does not auto-run from Git pushes
- you run it manually only when you want to destroy `dev`, `qa`, or `prod`

### Step 10: Authorize protected resources on first use

Azure DevOps may ask for approval the first time a pipeline uses:

- the service connection
- the secure file
- the reusable environments

If a run pauses because of resource authorization:

1. Open the run.
2. Read the authorization message.
3. Approve the resource for the pipeline.
4. Re-run if needed.

## How to use the provision pipeline

### Automatic use

The provision pipeline has:

- `trigger: main`

So a push to `main` can start the pipeline automatically.

### Manual use

You can also run it manually:

1. Open `AKS Terraform Provision`.
2. Select `Run pipeline`.
3. Confirm the branch.
4. Start the run.

### What each stage means

#### Stage 1: TerraformValidate

This stage:

- publishes the Terraform code as a pipeline artifact
- installs Terraform
- runs `terraform init`
- runs `terraform validate`

#### Stage 2: TerraformDevPlan

This stage:

- downloads the Terraform artifact
- downloads the SSH public key
- initializes Terraform with `aks-dev.tfstate`
- runs the dev plan
- publishes a dev plan bundle with the `.tfplan` file and a readable `.txt` summary

#### Stage 3: DeployDevAKSCluster

This stage:

- waits for the `dev` environment approval
- applies the exact reviewed dev plan

#### Stage 4: TerraformQaPlan

This stage:

- initializes Terraform with `aks-qa.tfstate`
- runs the qa plan
- publishes a qa plan bundle

#### Stage 5: DeployQaAKSCluster

This stage:

- waits for the `qa` environment approval
- applies the exact reviewed qa plan

#### Stage 6: TerraformProdPlan

This stage:

- initializes Terraform with `aks-prod.tfstate`
- runs the prod plan
- publishes a prod plan bundle

#### Stage 7: DeployProdAKSCluster

This stage:

- waits for the `prod` environment approval
- applies the exact reviewed prod plan

Note:

- the dev, qa, and prod tracks run independently after the shared validation stage

## How to use the destroy pipeline

### When to use it

Use the destroy pipeline only when you intentionally want to delete the dev, QA, or prod AKS environment.

Do not use it for normal updates.

### How to run it

1. Open `AKS Terraform Destroy`.
2. Select `Run pipeline`.
3. Choose `targetEnvironment`:
   - `dev`
   - `qa`
   - `prod`
4. Confirm the branch.
5. Start the run.

### What each stage means

#### Stage 1: TerraformValidate

Checks the Terraform code before any destroy action begins.

#### Stage 2: TerraformDestroyPlan

This stage:

- downloads the Terraform artifact
- downloads the SSH public key
- initializes Terraform against the selected state file
- runs `terraform plan -destroy`
- publishes a destroy plan bundle with the binary plan and readable summary

#### Stage 3: TerraformDestroy

This stage:

- waits for approval on `dev`, `qa`, or `prod`
- downloads the reviewed destroy plan
- applies that exact destroy plan

## What approvers should review

Before approving either provision or destroy:

1. Open the pipeline run.
2. Open the published plan artifact.
3. Read the `.txt` summary created by `terraform show`.
4. Confirm the resources and changes match expectations.
5. Approve only after review.

Artifact names you will see:

- `dev-plan`
- `qa-plan`
- `prod-plan`
- `dev-destroy-plan`
- `qa-destroy-plan`
- `prod-destroy-plan`

## Beginner checklist

You are ready when all of these are true:

- the Terraform extension is available
- the service connection `terraform-aks-azurerm-svc-con` exists
- the secure file `aks-terraform-devops-ssh-key-ubuntu.pub` exists
- the Terraform backend storage exists and is reachable
- the reusable environments `dev`, `qa`, and `prod` exist
- the `dev`, `qa`, and `prod` environments have approval checks
- the provision pipeline exists
- the destroy pipeline exists

## Common problems and how to fix them

### Problem: Terraform task is not recognized

Cause:

- the Terraform extension is not installed

Fix:

1. Install the Terraform extension.
2. Reopen the pipeline editor.
3. Re-run validation.

### Problem: Secure file download fails

Possible causes:

- the file was not uploaded
- the name does not match the YAML
- the pipeline is not authorized to use it

Fix:

1. Open `Pipelines` -> `Library` -> `Secure files`.
2. Confirm the file exists as `aks-terraform-devops-ssh-key-ubuntu.pub`.
3. Authorize the pipeline if prompted.

### Problem: Terraform init fails against the backend

Possible causes:

- the backend storage account or container does not exist
- the service connection does not have access

Fix:

1. Verify the resource group `TerraformStorageAccount` exists.
2. Verify the storage account `strgterraformvp` exists.
3. Verify the blob container `tfstatefiles` exists.
4. Verify the service connection can access them.

### Problem: Pipeline does not pause for approval after plan

Possible causes:

- the `dev`, `qa`, or `prod` environment does not exist
- the environment exists but has no approval check
- the approval check is configured on the wrong environment

Fix:

1. Open `Pipelines` -> `Environments`.
2. Confirm `dev`, `qa`, and `prod` exist.
3. Confirm all three have an `Approval` check.
4. Confirm the deployment jobs in the YAML point to `dev`, `qa`, and `prod`.

## Safe operating recommendations

- test dev first before promoting to qa
- test qa before using prod
- keep the `prod` approvers limited to a small trusted group
- review every plan artifact before approval

## Quick summary

If you want the shortest setup checklist:

1. Install the Terraform extension if Azure DevOps does not recognize the Terraform tasks.
2. Create the service connection `terraform-aks-azurerm-svc-con`.
3. Upload the secure file `aks-terraform-devops-ssh-key-ubuntu.pub`.
4. Create three reusable environments: `dev`, `qa`, and `prod`.
5. Add approval checks with a 120-minute timeout to `dev`, `qa`, and `prod`.
6. Create the provision pipeline from `AKS-Terraform/Terraform-provision-aks-cluster-pipeline.yml`.
7. Create the destroy pipeline from `AKS-Terraform/Terraform-destroy-aks-cluster-pipeline.yml`.
8. Review plan artifacts before every approval.
