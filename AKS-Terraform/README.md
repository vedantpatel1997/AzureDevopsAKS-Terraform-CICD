# AKS Terraform Project Guide

This folder contains the Terraform code and Azure DevOps YAML pipelines used to provision and destroy AKS environments.

This guide is written for beginners. Follow it from top to bottom the first time you set up the project.

## What this project contains

Use these two YAML files as the active pipelines for this Terraform project:

- `Terraform-provision-aks-cluster-pipeline.yml`
- `Terraform-destroy-aks-cluster-pipeline.yml`

Important:

- The provision pipeline creates or updates AKS infrastructure.
- The destroy pipeline tears down AKS infrastructure.
- The destroy pipeline is manual only.
- The destroy pipeline is designed to use Azure DevOps Environment approvals.

Other important folders:

- `Terraform-manifests/`: the Terraform code.
- `kube-manifests/`: Kubernetes workload manifests that can be deployed after the cluster is created.
- `aks-prod-sshkeys-terraform/`: local SSH key files used outside Azure DevOps. The pipeline itself uses a Secure File in Azure DevOps.

## How the current pipelines work

### Provision pipeline

File:

- `Terraform-provision-aks-cluster-pipeline.yml`

What it does:

1. Triggers automatically when code is pushed to the `main` branch.
2. Publishes the Terraform code as a pipeline artifact.
3. Runs `terraform init` and `terraform validate`.
4. Deploys the `dev` AKS environment.
5. Deploys the `qa` AKS environment.

Important behavior:

- `dev` and `qa` are deployed as separate Azure DevOps deployment jobs.
- After validation, the `dev` and `qa` stages can run in parallel.
- This pipeline currently does not require manual approval in YAML.
- If you want approvals for provision later, add them to the Azure DevOps Environments named `dev` and `qa`.

### Destroy pipeline

File:

- `Terraform-destroy-aks-cluster-pipeline.yml`

What it does:

1. Does not trigger automatically from Git.
2. Lets you choose which environment to destroy: `dev` or `qa`.
3. Validates the Terraform code.
4. Creates a Terraform destroy plan for only the selected environment.
5. Publishes the destroy plan as an artifact for review.
6. Waits for Azure DevOps Environment approval on the destroy environment.
7. Applies the exact reviewed destroy plan after approval.

Important behavior:

- One environment is destroyed per run.
- The destroy pipeline uses deployment environments:
  - `aks-destroy-dev`
  - `aks-destroy-qa`
- The approval timeout should be configured on those Azure DevOps Environments, not in YAML.

## Names this project expects

The current YAML files are already wired to these names. If you change any of them in Azure DevOps or Azure, update the YAML too.

### Azure DevOps names

- Provision environment 1: `dev`
- Provision environment 2: `qa`
- Destroy environment 1: `aks-destroy-dev`
- Destroy environment 2: `aks-destroy-qa`
- Secure file: `aks-terraform-devops-ssh-key-ubuntu.pub`
- Service connection: `terraform-aks-azurerm-svc-con`

### Azure backend names for Terraform state

- Resource group: `TerraformStorageAccount`
- Storage account: `strgterraformvp`
- Blob container: `tfstatefiles`

### Terraform state files used by this repo

- `aks-dev.tfstate`
- `aks-qa.tfstate`

## Before you start

Make sure you have these prerequisites:

1. An Azure DevOps project.
2. This repository connected to Azure DevOps Repos or GitHub.
3. Permission to create pipelines, environments, and service connections in Azure DevOps.
4. Permission in Azure to create and delete AKS-related resources.
5. A Terraform backend storage account already created in Azure.
6. The SSH public key file that the pipeline will upload as a Secure File.
7. The Azure DevOps Terraform extension installed if your organization does not already have the Terraform tasks available.

Simple check:

- If Azure DevOps does not recognize `TerraformInstaller@1` or `TerraformTask@5`, install the Terraform extension first.

## Recommended one-time setup order

Set up the project in this order:

1. Confirm your repository and branch.
2. Install the Terraform task extension if needed.
3. Create the Azure Resource Manager service connection.
4. Make sure the service connection has Azure permissions.
5. Upload the SSH public key as a Secure File.
6. Create Azure DevOps Environments for provision and destroy.
7. Add approvals to the destroy environments.
8. Create the provision pipeline.
9. Create the destroy pipeline.
10. Run a test deployment.
11. Run a test destroy in a non-production environment only after approvals are confirmed.

## Step-by-step Azure DevOps setup

### Step 1: Confirm the repository and branch

Before creating pipelines, check the following:

1. The repository contains the `AKS-Terraform` folder.
2. The active branch for automatic deployments is `main`.
3. The file `AKS-Terraform/Terraform-provision-aks-cluster-pipeline.yml` exists in the branch you will use.
4. The file `AKS-Terraform/Terraform-destroy-aks-cluster-pipeline.yml` exists in the branch you will use.

Why this matters:

- The provision pipeline is configured with `trigger: main`.
- If your default branch is not `main`, either rename your branch strategy or update the YAML trigger.

### Step 2: Install the Terraform Azure DevOps extension if needed

This repo uses these pipeline tasks:

- `TerraformInstaller@1`
- `TerraformTask@5`

If those tasks are not already available in your Azure DevOps organization:

1. Open Azure DevOps.
2. Go to the Azure DevOps Marketplace.
3. Find the Terraform extension used by your organization for Azure Pipelines.
4. Install it into your Azure DevOps organization.
5. Return to your project and verify the Terraform tasks are now recognized.

Beginner tip:

- If pipeline creation fails with a message like "task not found", this extension is usually the missing piece.

### Step 3: Create the Azure Resource Manager service connection

The YAML expects a service connection with this exact name:

- `terraform-aks-azurerm-svc-con`

Create it in Azure DevOps:

1. Open `Project settings`.
2. Select `Service connections`.
3. Select `New service connection`.
4. Choose `Azure Resource Manager`.
5. Follow the Azure sign-in flow.
6. Create the connection with the name `terraform-aks-azurerm-svc-con`.
7. Save it.

Recommended approach:

- If your Azure DevOps organization supports it, use workload identity federation for better security.

### Step 4: Make sure the service connection has Azure permissions

Creating the service connection is not enough by itself. It must also have the right Azure access.

The service connection needs access to:

- The resource group or subscription where AKS resources will be created.
- The Terraform backend resource group.
- The storage account `strgterraformvp`.
- The blob container `tfstatefiles`.

What to check:

1. In Azure, open the subscription or resource group scope used by this project.
2. Open `Access control (IAM)`.
3. Confirm the identity behind the service connection has the required role assignments.
4. Confirm it can read and write Terraform state in the storage account.

If this is missing, common errors are:

- Terraform init fails against the backend.
- Terraform plan cannot read the state.
- Terraform apply cannot create or delete Azure resources.

### Step 5: Upload the SSH public key as a Secure File

Both pipelines expect this exact secure file name:

- `aks-terraform-devops-ssh-key-ubuntu.pub`

Upload it in Azure DevOps:

1. Go to `Pipelines`.
2. Open `Library`.
3. Open `Secure files`.
4. Select `+ Secure file`.
5. Upload the public key file.
6. Make sure the uploaded file name exactly matches `aks-terraform-devops-ssh-key-ubuntu.pub`.
7. Authorize the pipelines to use the file.

Important:

- Upload the public key file, not the private key.
- If the file name does not match the YAML, the pipeline will fail.

### Step 6: Create the Azure DevOps Environments

This project uses Azure DevOps Environments for deployment history and approvals.

Create these four environments:

- `dev`
- `qa`
- `aks-destroy-dev`
- `aks-destroy-qa`

How to create them:

1. Open `Pipelines`.
2. Select `Environments`.
3. Select `New environment`.
4. Create `dev`.
5. Repeat for `qa`.
6. Repeat for `aks-destroy-dev`.
7. Repeat for `aks-destroy-qa`.

What each one is used for:

- `dev`: provision pipeline deployment history for the dev environment.
- `qa`: provision pipeline deployment history for the qa environment.
- `aks-destroy-dev`: destroy pipeline approval and deployment history for destroying dev.
- `aks-destroy-qa`: destroy pipeline approval and deployment history for destroying qa.

### Step 7: Add approval checks to the destroy environments

This is the most important safety step for the destroy pipeline.

Add approvals to:

- `aks-destroy-dev`
- `aks-destroy-qa`

How to configure approval:

1. Open `Pipelines`.
2. Open `Environments`.
3. Select `aks-destroy-dev`.
4. Open `Approvals and checks`.
5. Add an `Approval` check.
6. Select the users or group who are allowed to approve destroy runs.
7. Set the timeout to `120 minutes`.
8. Save the approval check.
9. Repeat the same steps for `aks-destroy-qa`.

What this does:

- The destroy deployment cannot start until someone approves it.
- If nobody approves it within 120 minutes, Azure DevOps blocks the deployment from proceeding.

Optional:

- If you also want approvals before provisioning, add approval checks to `dev` and `qa`.
- That is optional and not required by the current YAML.

### Step 8: Create the provision pipeline

Create the first pipeline from the provision YAML:

1. Open `Pipelines`.
2. Select `New pipeline`.
3. Choose the repository that contains this project.
4. Choose `Existing Azure Pipelines YAML file`.
5. Select `AKS-Terraform/Terraform-provision-aks-cluster-pipeline.yml`.
6. Review the YAML preview.
7. Save the pipeline with a clear name such as `AKS Terraform Provision`.

What to expect after creation:

- Because this pipeline has a `main` branch trigger, future commits to `main` will start it automatically.
- Depending on your Azure DevOps flow, the first save may also offer a run. If your setup is not complete yet, cancel that first run and finish the remaining steps first.

### Step 9: Create the destroy pipeline

Create the second pipeline from the destroy YAML:

1. Open `Pipelines`.
2. Select `New pipeline`.
3. Choose the same repository.
4. Choose `Existing Azure Pipelines YAML file`.
5. Select `AKS-Terraform/Terraform-destroy-aks-cluster-pipeline.yml`.
6. Review the YAML preview.
7. Save the pipeline with a clear name such as `AKS Terraform Destroy`.

What to expect after creation:

- This pipeline will not auto-run from Git pushes because it has `trigger: none`.
- You will run it manually only when you want to destroy `dev` or `qa`.

### Step 10: Authorize the resources on first use

Azure DevOps may ask for permission the first time a pipeline uses a protected resource.

Be ready to authorize:

- The service connection `terraform-aks-azurerm-svc-con`
- The secure file `aks-terraform-devops-ssh-key-ubuntu.pub`
- The Azure DevOps Environments used by the deployment jobs

If a run pauses with an authorization message:

1. Open the failed or waiting run.
2. Read the authorization prompt.
3. Approve the resource for the pipeline.
4. Re-run the pipeline if needed.

## How to use the provision pipeline

### What happens when you commit to main

The provision pipeline is configured with:

- `trigger: main`

So when you push a change to `main`, Azure DevOps will:

1. Start the provision pipeline.
2. Validate the Terraform code.
3. Deploy `dev`.
4. Deploy `qa`.

### How to run the provision pipeline manually

You can also start it manually:

1. Open the `AKS Terraform Provision` pipeline.
2. Select `Run pipeline`.
3. Confirm the branch.
4. Start the run.

### What each stage in the provision pipeline means

#### Stage 1: TerraformValidate

This stage:

- Publishes the Terraform files as an artifact.
- Installs Terraform on the build agent.
- Runs `terraform init`.
- Runs `terraform validate`.

Why it exists:

- It checks the Terraform syntax and backend configuration before trying to deploy resources.

#### Stage 2: DeployDevAKSCluster

This stage:

- Downloads the SSH public key from Secure Files.
- Initializes Terraform with the `aks-dev.tfstate` backend key.
- Creates a Terraform plan for `dev`.
- Applies that plan.

#### Stage 3: DeployQaAKSCluster

This stage:

- Downloads the SSH public key from Secure Files.
- Initializes Terraform with the `aks-qa.tfstate` backend key.
- Creates a Terraform plan for `qa`.
- Applies that plan.

## How to use the destroy pipeline

### When to use it

Use the destroy pipeline only when you intentionally want to delete an AKS environment and its Terraform-managed resources.

Do not use it for normal updates.

### How to run it

1. Open the `AKS Terraform Destroy` pipeline.
2. Select `Run pipeline`.
3. Choose the `targetEnvironment` parameter:
   - `dev`
   - `qa`
4. Confirm the branch.
5. Start the run.

### What each stage in the destroy pipeline means

#### Stage 1: TerraformValidate

This checks the Terraform code before any destroy work happens.

#### Stage 2: TerraformDestroyPlan

This stage:

- Downloads the Terraform artifact.
- Downloads the SSH public key.
- Initializes Terraform against the selected state file.
- Runs `terraform plan -destroy`.
- Publishes the reviewed destroy plan artifact.

Why this is important:

- It lets you review what Terraform plans to delete before the actual destroy begins.

#### Stage 3: TerraformDestroy

This stage:

- Waits on the Azure DevOps Environment approval.
- Downloads the reviewed destroy plan artifact.
- Initializes Terraform.
- Applies the exact destroy plan that was already created.

Why this is safer:

- It prevents the destroy step from generating a new and different plan after approval.

### What to review before approving destroy

Before approving the destroy environment:

1. Open the pipeline run.
2. Open the artifact named:
   - `dev-destroy-plan` for dev runs, or
   - `qa-destroy-plan` for qa runs
3. Open the `.txt` plan summary.
4. Confirm the resources listed for deletion are the ones you expect.
5. Approve only after verifying the plan.

## Beginner checklist: first successful setup

You are ready when all of the following are true:

- The Terraform task extension is available.
- The service connection `terraform-aks-azurerm-svc-con` exists.
- The SSH Secure File exists with the correct name.
- The Terraform backend storage exists and is reachable.
- The environments `dev`, `qa`, `aks-destroy-dev`, and `aks-destroy-qa` exist.
- The destroy environments have approval checks with a 120-minute timeout.
- The provision pipeline has been created.
- The destroy pipeline has been created.

## Common problems and how to fix them

### Problem: Terraform task is not recognized

Possible cause:

- The Terraform extension is not installed in Azure DevOps.

Fix:

1. Install the Terraform extension.
2. Reopen the pipeline editor.
3. Re-run validation.

### Problem: Secure file download fails

Possible causes:

- The secure file was not uploaded.
- The file name does not match the YAML.
- The pipeline was not authorized to use the file.

Fix:

1. Open `Pipelines` -> `Library` -> `Secure files`.
2. Confirm the file exists as `aks-terraform-devops-ssh-key-ubuntu.pub`.
3. Authorize the pipeline if prompted.

### Problem: Terraform init fails against the backend

Possible causes:

- The backend storage account or container does not exist.
- The service connection does not have access.

Fix:

1. Verify the resource group `TerraformStorageAccount` exists.
2. Verify the storage account `strgterraformvp` exists.
3. Verify the blob container `tfstatefiles` exists.
4. Verify the service connection can access them.

### Problem: Deployment fails with authorization errors

Possible cause:

- The service connection does not have the needed Azure role assignments.

Fix:

1. Open Azure IAM for the target scope.
2. Check the identity behind the service connection.
3. Add the necessary roles.
4. Run the pipeline again.

### Problem: Destroy pipeline does not pause for approval

Possible causes:

- The environment `aks-destroy-dev` or `aks-destroy-qa` does not exist.
- The environment exists, but no approval check was added.
- The deployment job points to a different environment name than the one you configured.

Fix:

1. Open the destroy YAML and confirm the environment name.
2. Open `Pipelines` -> `Environments`.
3. Confirm the environment exists with the exact same name.
4. Confirm an `Approval` check is configured.

### Problem: The provision pipeline does not auto-run

Possible causes:

- The change was not pushed to `main`.
- The pipeline was created against a different branch.
- Triggers are disabled in Azure DevOps settings.

Fix:

1. Confirm your commit reached `main`.
2. Confirm the pipeline points to the correct YAML file.
3. Check pipeline trigger settings in Azure DevOps.

## If you change names later

If you rename any of these, update both Azure DevOps and the YAML files:

- service connection names
- secure file names
- environment names
- Terraform backend resource names
- branch trigger names

If the names do not match, the pipelines usually fail immediately.

## Safe operating recommendations

- Test the provision pipeline in a non-production subscription first.
- Test the destroy pipeline only on a disposable environment first.
- Keep destroy approvals limited to a small admin or platform group.
- Review destroy plan artifacts before every approval.
- Avoid changing pipeline names, environment names, and service connection names unless you also update the YAML.

## Quick summary

If you only want the shortest version of the setup, do this:

1. Install the Terraform extension if Azure DevOps does not recognize the Terraform tasks.
2. Create the service connection `terraform-aks-azurerm-svc-con`.
3. Upload the secure file `aks-terraform-devops-ssh-key-ubuntu.pub`.
4. Create environments `dev`, `qa`, `aks-destroy-dev`, and `aks-destroy-qa`.
5. Add 120-minute approval checks to `aks-destroy-dev` and `aks-destroy-qa`.
6. Create the provision pipeline from `AKS-Terraform/Terraform-provision-aks-cluster-pipeline.yml`.
7. Create the destroy pipeline from `AKS-Terraform/Terraform-destroy-aks-cluster-pipeline.yml`.
8. Run the provision pipeline.
9. Run the destroy pipeline manually only when needed.
