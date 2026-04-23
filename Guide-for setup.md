# 🚀 Terraform Drift Detection on Azure — Complete Setup Guide
### GitHub Actions + OIDC + Slack Notifications + Manual Approval Gates

> **A production-grade guide** to deploy Terraform infrastructure on Azure using passwordless OIDC authentication, automated drift detection, Slack alerts, and safe destroy workflows with manual approval gates.

---

## 📋 Table of Contents

| # | Section | Description |
|---|---------|-------------|
| 0 | [Prerequisites](#prerequisites) | OIDC setup, required files, Azure CLI commands |
| 1 | [Role Assignment (CLI)](#step-1--manually-assign-the-contributor-role-cli) | Set variables, check & assign Contributor role |
| 2 | [Project Structure](#project-structure) | Folder layout and key files explained |
| 3 | [Bootstrap the Backend](#step-2--bootstrap-the-backend-run-once-locally) | One-time Terraform backend setup |
| 4 | [Slack Notifications](#step-4--add-slack-notifications) | Create app, webhook, and GitHub secret |
| 5 | [Manual Approval Gate](#step-5--add-manual-approval-before-destroy) | Environment-based approval before `terraform destroy` |
| 6 | [Teardown](#teardown) | Destroy infra, backend, and OIDC connector |

---

## Prerequisites

### 1. Required Tools

> ⚠️ **Install these before running any script.**

- **Azure CLI**
  ```shell
  az version
  ```
  Not installed? 👉 https://learn.microsoft.com/cli/azure/install-azure-cli

- **GitHub CLI**
  ```shell
  gh --version
  ```
  Not installed? 👉 https://cli.github.com/

- **jq**
  ```shell
  jq --version
  ```
  Not installed? 👉 https://stedolan.github.io/jq/download/

---

### 2. Azure Permissions Required

Your Azure user must have:
- Owner **or** User Access Administrator on the subscription
- Permission to create App Registrations

**Verify your current permissions:**
```shell
az role assignment list --assignee $(az ad signed-in-user show --query id -o tsv) -o table
```

---

### 3. GitHub Permissions Required

You must have **Admin access** to the repo: `yourrepo/Terraform-Drift-Detection`

Check login status:
```shell
gh auth status
```

Not logged in?
```shell
gh auth login
```

---

### 4. Initial Setup Checklist

Before anything else, get these in place:

- [Terraform CLI](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) installed
- Clone the repo: [Terraform-Drift-Detection](https://github.com/mrbalraj007/Terraform-Drift-Detection.git)
- 🔗 Configure an [OIDC connection](https://github.com/mrbalraj007/GitHub-Action-Azure_OpenID_Connect-OIDC/blob/main/How_to_Configure_OIDC_with_Azure.md) for passwordless Azure authentication
- 📥 Download the [OIDC setup script](https://github.com/mrbalraj007/GitHub-Action-Azure_OpenID_Connect-OIDC/blob/main/oidc.sh)
- 📥 Download [fics.json](https://github.com/mrbalraj007/GitHub-Action-Azure_OpenID_Connect-OIDC/blob/main/fics.json)

---

### 5. Configure `fics.json` *(Required)*

Create `fics.json` before running the script. This must match your GitHub Actions environment name (`dev`):

```json
[
  {
    "name": "github-dev-env",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:yourrepo/Terraform-Drift-Detection:environment:dev",
    "audiences": [
      "api://AzureADTokenExchange"
    ]
  }
]
```

---

## Project Structure

```
TERRAFORM-DRIFT-DETECTION/
│
├── .github/
│   ├── workflows/
│   │   ├── drift-detection.yml             # ✅ Nightly drift check + GitHub Issues
│   │   ├── destroy_resources.yml           # ✅ Destroys the environment/resources
│   │   ├── Dummy_Azure_login_validate.yml  # ✅ For dummy Azure login testing
│   │   ├── TBT-With_MSTeam_drift-detection.ps1  # ✅ MS Teams integration (WIP)
│   │   ├── terraform_CI_CD_JOB.yml         # ✅ CI/CD — Plan on PR, Apply on merge
│   │   └── terraform_push_scan.yml         # ✅ Push and Pull scanning
│   │
│   └── pull_request_template.md            # ✅ PR template
│
├── All_ScreenShot/
│
├── bootstrap/
│   ├── main.tf       # ✅ Creates the storage backend resources
│   ├── output.tf
│   └── variables.tf
│
├── OIDC_Setup_Script/
│   ├── delete-oidc-app.sh  # ✅ Deletes the OIDC connection
│   ├── fics.json           # ✅ Federated identity credential config
│   └── oidc.sh             # ✅ Creates the OIDC connection
│
├── .gitignore
├── 01.create-backend-secrets.sh  # ✅ Creates storage + backend container secrets in environment
├── backend.tf                    # ✅ Backend config for tfstate file
├── main.tf                       # ✅ NSG + Resource Group
├── outputs.tf                    # ✅ Useful outputs
├── providers.tf                  # ✅ AzureRM provider
└── variables.tf                  # ✅ All configurable values
```

---

## How to Configure OIDC

```shell
cd OIDC_Setup_Script/

ls -l
# total 20
# -rwxr-xr-x 1 Administrator 197121 5458 Apr 23 08:18 delete-oidc-app.sh*
# -rw-r--r-- 1 Administrator 197121 1134 Apr 23 08:18 fics.json
# -rwxr-xr-x 1 Administrator 197121 7407 Apr 23 11:02 oidc.sh*

# Configure OIDC
./oidc.sh demo-github-azure-oidc-connection yourrepo/Terraform-Drift-Detection ./fics.json dev
```

**Parameters:**
- `APP_NAME` — the Azure AD application name
- `REPO` — your GitHub repo in `ORG/REPO` format
- `dev` — environment name

> [!NOTE]
> Run the above command in a **bash terminal**.

<details>
<summary><b>📋 Expected output from oidc.sh</b></summary>

```shell
==============================================
 Azure OIDC + GitHub Environment Secret Setup
==============================================
App Name    : demo-github-azure-oidc-connection
Repo        : yourrepo/Terraform-Drift-Detection
FICS File   : ./fics.json
Environment : dev
==============================================

[Azure] Checking login status...
[Azure] Active subscription: ["XXXXXXXXXXXXXXXXXXXXXX", "DevOpsLearning"]
Do you want to use the above subscription? (Y/n) Y

[Azure] Fetching Subscription ID...
  SUB_ID: XXXXXXXXXXXXXXXXXXXXXX
[Azure] Fetching Tenant ID...
  TENANT_ID: XXXXXXXXXXXXXXXXXXXXXX

[Azure] Configuring App Registration...
  Creating new AD app: demo-github-azure-oidc-connection...
  Sleeping 30s for app provisioning...
  APP_ID: 4acf655a-0323-41bf-9223-b7ba713832e8

[Azure] Creating Federated Identity Credentials...
  Creating FIC 'prfic'      → repo:yourrepo/Terraform-Drift-Detection:pull_request
  Creating FIC 'mainfic'    → repo:yourrepo/Terraform-Drift-Detection:ref:refs/heads/main
  Creating FIC 'masterfic'  → repo:yourrepo/Terraform-Drift-Detection:ref:refs/heads/master
  Creating FIC 'envfic-dev' → repo:yourrepo/Terraform-Drift-Detection:environment:dev

[GitHub] Setting secrets in environment 'dev'...
  ✔ AZURE_CLIENT_ID set
  ✔ AZURE_SUBSCRIPTION_ID set
  ✔ AZURE_TENANT_ID set

==============================================
 Setup Complete!
==============================================
```

</details>

Once done, verify the secrets are in place:

> **Repo → Settings → Environments → dev → Secrets**

---

<details>
<summary><b>🔧 Useful Azure CLI Commands</b></summary>
<br>

**Get your Subscription ID:**
```bash
az account show --query id -o tsv
```

**Get Subscription ID + Name together:**
```bash
az account show --query '[id,name]' -o tsv
```

**List all subscriptions in table format:**
```bash
az account list --query '[].{Name:name, ID:id, State:state}' -o table
```

**Get the active subscription as JSON:**
```bash
az account show --query '{SubscriptionID:id, Name:name}' -o json
```

</details>

---

## Step 1 — Create a Service Principal

The OIDC app registration needs a corresponding Service Principal in Azure AD.

**Create it:**
```shell
az ad sp create --id <AZURE_CLIENT_ID>
```

**Get the Client ID:**
```shell
az ad app list --display-name demo-github-azure-oidc-connection --query "[].appId" -o tsv
```

**Verify the Service Principal:**
```shell
az ad sp list --filter "appId eq '<AZURE_CLIENT_ID>'" -o table
```

**Confirm it exists by display name:**
```shell
az ad sp list --display-name "demo-github-azure-oidc-connection" -o table
```

**Delete it (if needed):**
```shell
az ad sp delete --id <AZURE_CLIENT_ID>
```

---

### Step 1.1 — Confirm Role Assignment

```shell
MSYS_NO_PATHCONV=1 az role assignment list \
  --assignee <SP_OBJECT_ID> \
  --scope /subscriptions/<SUB_ID> \
  -o table
```

**Get `SP_OBJECT_ID`:**
```shell
az ad app list \
  --display-name demo-github-azure-oidc-connection \
  --query "[].appId" -o tsv
```

**Get `SUB_ID`:**
```shell
az account list --query '[].{Name:name, ID:id, State:state}' -o table
```

> If the output is **empty**, the role is missing — proceed to the next step.

> [!CAUTION]
> Use `MSYS_NO_PATHCONV=1` when running in **Git Bash**. In PowerShell, you can omit it.

---

### Step 1.2 — Assign the Contributor Role

```shell
MSYS_NO_PATHCONV=1 az role assignment create \
  --assignee-object-id <SP_OBJECT_ID> \
  --assignee-principal-type ServicePrincipal \
  --role Contributor \
  --scope /subscriptions/<SUB_ID>
```

**Get `SP_OBJECT_ID` by App ID:**
```shell
az ad sp list \
  --filter "appId eq '4acf655a-0323-41bf-9223-b7ba713832e8'" \
  --query "[0].{SP_ObjectId:id, AppId:appId, DisplayName:displayName}" \
  -o table
```

**Verify the assignment:**
```shell
az role assignment list --assignee <SP_OBJECT_ID> --scope /subscriptions/<SUB_ID> -o table
```

---

**Where to find these values in the Azure Portal:**

```
SUB_ID:
  portal.azure.com
    └── Subscriptions
          └── DevOpsLearning
                └── Overview → Subscription ID ✅

SP_ID (Object ID):
  portal.azure.com
    └── Enterprise Applications
          └── Search: demo-github-azure-oidc-connection
                └── Overview → Object ID ✅

      OR

    └── App Registrations → All Applications
          └── demo-github-azure-oidc-connection
                └── Overview → Managed application in local directory → Object ID ✅
```

**Quick reference:**

| ID | Portal Location | Field Name |
|----|-----------------|------------|
| `SUB_ID` | Subscriptions → Your Subscription → Overview | Subscription ID |
| `APP_ID` | App Registrations → Your App → Overview | Application (client) ID |
| `SP_ID` | Enterprise Applications → Your App → Overview | Object ID |

---

> [!NOTE]
> If the CLI role assignment fails, you can do it manually via the Azure Portal:
>
> **Subscriptions → Your Subscription → Access Control (IAM) → Add → Add Role Assignment**
> 1. Select `Contributor` from **Privileged administrator roles** → click **Next**
> 2. Assign access to a service principal, search for `demo-github-azure-oidc-connection`
> 3. Click **Review + assign**

---

## Step 2 — Bootstrap the Backend *(Run Once, Locally)*

```bash
cd bootstrap/
terraform init
terraform apply
```

> This creates a **backend storage account** for your pipeline to store the `tfstate` file remotely.

### Step 2.1 — Get the Storage Account Key *(Optional)*

If you need to add the storage key to GitHub Secrets:

```bash
terraform output -raw storage_account_key
```

---

## Step 3 — Assign `Storage Blob Data Contributor`

This is **mandatory** when using `ARM_USE_AZUREAD: true` in your workflow. With Azure AD token authentication, Terraform authenticates to the storage backend using an AD token rather than storage account keys — which means the Service Principal needs explicit blob-level access.

Think of it this way:

| Component | Purpose |
|-----------|---------|
| App Registration / OIDC | **Who you are** (Identity) |
| Role on Storage Account | **What you can do** (Permission) |

---

**Get your subscription and tenant details:**
```shell
az account show --query "{subscription:id, tenant:tenantId}" -o table
```

**List all storage accounts:**
```shell
az storage account list \
  --query "[].{Name:name, ResourceGroup:resourceGroup, Location:location}" \
  -o table
```

**Get the Storage Account Resource ID:**
```shell
az storage account show \
  --name <STORAGE_NAME> \
  --resource-group <RG_NAME> \
  --query id -o tsv
```

Expected output:
```
/subscriptions/.../resourceGroups/rg-terraform-state/providers/Microsoft.Storage/storageAccounts/mystorageacct01
```

Save it:
```shell
STORAGE_SCOPE="/subscriptions/.../storageAccounts/mystorageacct01"
```

**Get the Service Principal Object ID:**
```shell
az ad sp show --id <APP_CLIENT_ID> --query id -o tsv
# Example: 7268b9bc-df91-4ca9-8596-50bcc4cfe56e
SP_OBJECT_ID="7268b9bc-df91-4ca9-8596-50bcc4cfe56e"
```

**Assign the role:**

> [!CAUTION]
> Git Bash users — prefix with `MSYS_NO_PATHCONV=1` to prevent path mangling.

```shell
MSYS_NO_PATHCONV=1 az role assignment create \
  --assignee-object-id "$SP_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" \
  --scope "$STORAGE_SCOPE"
```

**Verify the assignment:**
```shell
MSYS_NO_PATHCONV=1 az role assignment list \
  --assignee-object-id "$SP_OBJECT_ID" \
  --scope "$STORAGE_SCOPE" \
  -o table
```

Expected:
```
Storage Blob Data Contributor   /subscriptions/.../storageAccounts/mystorageacct01
```

---

<details>
<summary><b>🖥️ GUI Alternative — Assign via Azure Portal</b></summary>
<br>

```
Azure Portal
  └── Storage Accounts
        └── <your-backend-storage-account>
              └── Access Control (IAM)
                    └── + Add → Add role assignment
                          ├── Role tab
                          │     └── Search: "Storage Blob Data Contributor" ✅
                          └── Members tab
                                └── Assign access to: User/group/service principal
                                      └── Select: "demo-github-azure-oidc-connection" ✅
```

1. Go to **Storage Accounts** → your backend storage account
2. Click **Access Control (IAM)** in the left sidebar
3. Click **+ Add** → **Add role assignment**
4. On the **Role** tab, search for `Storage Blob Data Contributor` → **Next**
5. On the **Members** tab, search for and select `demo-github-azure-oidc-connection`
6. Click **Review + assign**

</details>

---

### Add Backend Secrets to GitHub Environment

Go to: **GitHub → Settings → Environments → dev → Secrets → Actions**

Add the following secrets:

| Secret Name | Example Value |
|-------------|---------------|
| `BACKEND_AZURE_RESOURCE_GROUP_NAME` | `rg-terraform-state` |
| `BACKEND_AZURE_STORAGE_ACCOUNT_NAME` | `tfstate12345` |
| `BACKEND_AZURE_STORAGE_ACCOUNT_CONTAINER_NAME` | `tfstate` |

Or run the included script:
```bash
chmod +x 01.create-backend-secrets.sh
./01.create-backend-secrets.sh your-repo/Terraform-Drift-Detection dev
```

Expected output:
```shell
✅ Repo: your-repo/Terraform-Drift-Detection
✅ Environment: dev
✅ Resource Group: rg-terraform-state
✅ Storage Account: tfstatemyproject002
✅ Container: tfstate
✔ BACKEND_AZURE_RESOURCE_GROUP_NAME set
✔ BACKEND_AZURE_STORAGE_ACCOUNT_NAME set
✔ BACKEND_AZURE_STORAGE_ACCOUNT_CONTAINER_NAME set
🎉 Secrets successfully created in environment 'dev'
```

**Verify all secrets via CLI:**
```shell
gh secret list --env dev --repo your-repo/Terraform-Drift-Detection
```

Expected:
```
NAME                                          UPDATED
AZURE_CLIENT_ID                               about 1 hour ago
AZURE_SUBSCRIPTION_ID                         about 1 hour ago
AZURE_TENANT_ID                               about 1 hour ago
BACKEND_AZURE_RESOURCE_GROUP_NAME             about 5 minutes ago
BACKEND_AZURE_STORAGE_ACCOUNT_CONTAINER_NAME  about 5 minutes ago
BACKEND_AZURE_STORAGE_ACCOUNT_NAME            about 5 minutes ago
```

---

### Step 2.2 — Push the Infrastructure Code to GitHub

Once you push to GitHub, Actions will automatically:

- Run `terraform plan` on every **Pull Request**
- Run `terraform apply` on every merge to **`main`**

---

## Step 4 — Add Slack Notifications

### Step 4.1 — Create a Slack Channel

1. Open Slack and click **`+`** next to **Channels** in the left sidebar
2. Click **Create a channel**
3. Fill in the details:
   - **Name:** `terraform-drift-alerts`
   - **Description:** `Terraform drift detection notifications from GitHub Actions`
   - **Visibility:** Private *(recommended)* or Public
4. Click **Create** and optionally add your team members

---

### Step 4.2 — Create a Slack App & Incoming Webhook

1. Go to [https://api.slack.com/apps](https://api.slack.com/apps)
2. Click **Create New App** → choose **From scratch**
3. Fill in:
   - **App Name:** `Terraform Drift Bot`
   - **Workspace:** Select your workspace
4. Click **Create App**

**Enable Incoming Webhooks:**

5. In the App settings, click **Incoming Webhooks** in the left sidebar
6. Toggle **Activate Incoming Webhooks** → `ON`
7. Scroll down and click **Add New Webhook to Workspace**
8. Select the channel: `#terraform-drift-alerts`
9. Click **Allow**

> ⚠️ **Copy the Webhook URL — it looks like:**
> ```
> https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX
> ```
> Save this somewhere safe — you'll need it in the next step.

---

### Step 4.3 — Add the Webhook URL to GitHub Secrets

1. Go to your GitHub repo → **Settings**
2. Click **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Fill in:
   - **Name:** `SLACK_WEBHOOK_URL`
   - **Value:** `https://hooks.slack.com/services/xxxx/xxxx/xxxx`
5. Click **Add secret**

Your repo secrets should now include:

```
✅ AZURE_CLIENT_ID
✅ AZURE_SUBSCRIPTION_ID
✅ AZURE_TENANT_ID
✅ SLACK_WEBHOOK_URL    ← NEW
```

---

## Step 5 — Add Manual Approval Before Destroy

### Why This Matters

GitHub Actions supports real approval gates via **Environments**. When a job references an environment with required reviewers:

- ⏸ The workflow **pauses**
- 👤 Approval is required from configured reviewers
- ✅ Only then does `terraform destroy` proceed

This is **auditable**, **native to GitHub**, and the **industry standard** for production destroy workflows.

---

### Step 5.1 — One-Time Setup in GitHub UI *(Mandatory)*

**Create the Environment:**

1. Repo → **Settings** → **Environments**
2. Click **New environment**
3. Name it **exactly**: `dev`
4. Click **Configure environment**

**Add Required Reviewers:**

1. Enable ✅ **Required reviewers**
2. Add yourself and/or your platform team
3. Click **Save**

That's it — no further changes needed in the UI.

---

### Step 5.2 — Troubleshooting: OIDC Error on Destroy

> [!NOTE]
> If you hit an authentication error during the destroy stage, you need to add a **Federated Credential** for the `destroy-approval` environment in Azure.

**Step A — Go to App Registration:**

```
Azure Portal
  └── Microsoft Entra ID
        └── App registrations
              └── demo-github-azure-oidc-connection
```

**Step B — Add a Federated Credential:**

- Click **Federated credentials** → **Add credential**
- Choose scenario: **GitHub Actions deploying Azure resources**
- Set **Entity Type** to `Environment` and enter `destroy-approval` as the environment name
- Save

After this fix, the full destroy flow runs cleanly:

```
✅ Azure login
✅ Terraform init
✅ Terraform destroy
✅ Slack notification sent
```

No pipeline changes needed. No new secrets. No workarounds.

---

## Teardown

Once you're done, clean up in this order:

**1. Run the destroy pipeline** to remove your infrastructure

**2. Destroy the Terraform backend:**
```bash
cd bootstrap/
terraform destroy --auto-approve
```

**3. Delete the OIDC app registration:**

```shell
# Preview only — no changes made
./delete-oidc-app.sh demo-github-azure-oidc-connection your-repo/Terraform-Drift-Detection dev --dry-run

# Run the actual cleanup
./delete-oidc-app.sh demo-github-azure-oidc-connection your-repo/Terraform-Drift-Detection dev
```

---

## GitHub Secrets — Quick Reference

**Get all three values in one shot:**
```shell
echo "CLIENT_ID=$(az ad app list --display-name demo-github-azure-oidc-connection --query '[].appId' -o tsv)"
echo "TENANT_ID=$(az account show --query tenantId -o tsv)"
echo "SUBSCRIPTION_ID=$(az account show --query id -o tsv)"
```

| Secret Name | Description |
|-------------|-------------|
| `AZURE_CLIENT_ID` | App Registration — Application (Client) ID |
| `AZURE_TENANT_ID` | Entra ID — Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure Subscription ID |

---

## 🔀 Git — Renaming a Branch

If you need to rename a branch and keep everything in sync:

**1. Confirm you're on the right branch:**
```shell
git branch
# The * should be on the branch you renamed
```

**2. Push the renamed branch to remote:**
```shell
git push origin -u NEW_BRANCH_NAME
# Example:
git push origin -u feature/new-login
```

The `-u` flag sets upstream tracking so future pushes work normally.

**3. Delete the old branch from remote:**
```shell
git push origin --delete OLD_BRANCH_NAME
# Example:
git push origin --delete feature/login-old
```

**4. Refresh in VS Code:**
```shell
git fetch --prune
```
This cleans up deleted remote branches so they stop showing in the UI.

---

## 📚 Reference Links

| Resource | Link |
|----------|------|
| OIDC Configuration Guide | [How_to_Configure_OIDC_with_Azure.md](https://github.com/mrbalraj007/GitHub-Action-Azure_OpenID_Connect-OIDC/blob/main/How_to_Configure_OIDC_with_Azure.md) |
| OIDC Setup Script | [oidc.sh](https://github.com/mrbalraj007/GitHub-Action-Azure_OpenID_Connect-OIDC/blob/main/oidc.sh) |
| OIDC Cleanup Script | [delete-oidc-app.sh](https://github.com/mrbalraj007/GitHub-Action-Azure_OpenID_Connect-OIDC/blob/main/delete-oidc-app.sh) |
| Federated Identity Config | [fics.json](https://github.com/mrbalraj007/GitHub-Action-Azure_OpenID_Connect-OIDC/blob/main/fics.json) |

---

*Built with 💙 using GitHub Actions + Terraform + Azure OIDC*