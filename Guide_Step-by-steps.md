# 🚀 Terraform Drift Detection on Azure Environment— Complete Setup Guide
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
1. **Required Tools (Install First)**

- BEFORE YOU RUN THE SCRIPT (VERY IMPORTANT)
- You MUST have these installed locally:
   - Azure CLI
        ```Shell
        az version
        ```
      - If not installed: 👉 https://learn.microsoft.com/cli/azure/install-azure-cli

  - GitHub CLI
      ```Shell
      gh --version
      ```
    - If not installed: 👉 https://cli.github.com/

  - jq
    ```Shell
    jq --version
    ```
  - If not installed: 👉 https://stedolan.github.io/jq/download/

2. **Azure Permissions You Need**
Your Azure user must have:

- Owner or User Access Administrator on the subscription
Permission to create App registrations

Permission to Check:
```Shell
az role assignment list --assignee $(az ad signed-in-user show --query id -o tsv) -o table
```


3. **GitHub Permissions You Need:** You must have `Admin access` to the repo:
`yourrepo/Terraform-Drift-Detection`

And you must be logged in:
```Shell
gh auth status
```

If not:
```Shell
gh auth login
```

Before anything else, get these three things in place:
- [Terraform CLI](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) must be installed
- Clone the [Repo: Terraform-Drift-Detection](https://github.com/mrbalraj007/Terraform-Drift-Detection.git)
- 🔗 Configure an [OIDC connection](https://github.com/mrbalraj007/GitHub-Action-Azure_OpenID_Connect-OIDC/blob/main/How_to_Configure_OIDC_with_Azure.md) for passwordless Azure authentication
- 📥 Download the [OIDC setup script](https://github.com/mrbalraj007/GitHub-Action-Azure_OpenID_Connect-OIDC/blob/main/oidc.sh)
- 📥 Download [fics.json](https://github.com/mrbalraj007/GitHub-Action-Azure_OpenID_Connect-OIDC/blob/main/fics.json)


4. update **fics.json** file (Example – REQUIRED)
Create `fics.json` before running the script:
```json

[
  {
    "name": "github-dev-env",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:your repo/Terraform-Drift-Detection:environment:dev",
    "audiences": [
      "api://AzureADTokenExchange"
    ]
  }
]

```
👉 This must match your GitHub Actions environment name (`dev`).

## Project Structure

```

└── .github/
    └── workflows/
        ├── terraform_CI_CD_JOB.yml                
        ├── Terraform - Format and Validate.yml    
│   
│       └── drift-detection.yml                    
        └── Dummy_Azure_login_validate.yml         
        └── TBT-With_MSTeam_drift-detection.ps1   when MS Team issue fixed


TERRAFORM-DRIFT-DETECTION/
│
├── .github/
│   ├── workflows/
│   │   ├── drift-detection.yml             # ✅ NEW — Nightly drift check + GitHub Issues
        ├── destroy_resources.yml         # ✅ To destroy the environment/resources              
│   │   ├── Dummy_Azure_login_validate.yml  # ✅ For dummy azue login testing
│   │   ├── TBT-With_MSTeam_drift-detection.ps1   # ✅ Will test it 
│   │   ├── terraform_CI_CD_JOB.yml   # ✅ CI/CD — Plan on PR, Apply on merge
│   │   └── terraform_push_scan.yml    # ✅ Push and Pull
│   │
│   └── pull_request_template.md  # ✅ For pull template
│
├── All_ScreenShot/
│
├── bootstrap/
│   ├── main.tf      # ✅ Creates the storage backend resources
│   ├── output.tf
│   └── variables.tf
│
├── Dont_Use_it/
│
├── OIDC_Setup_Script/
│   ├── delete-oidc-app.sh  # ✅ To delete a OIDC connection 
│   ├── fics.json           # ✅ To create a file and connection
│   └── oidc.sh             # ✅ To create a OIDC connection     
│
├── .gitignore                  # ✅ To ignore files 
├── 01.create-backend-secrets.sh # ✅ To create storage and backend container secret in environment
├── backend.tf                   # ✅ To use the backend store tfstate file 
├── Git_GitHub_Complete_Notes.docx
├── Guide_Step-by-steps.md
├── main.tf                 # ✅ NEW — NSG + Resource Group
├── outputs.tf              # ✅ NEW — Useful outputs
├── providers.tf             # ✅ NEW — AzureRM provider
├── Terraform-Azure-Full-Architecture.drawio
└── variables.tf            # ✅ NEW — All configurable values
```

- **How to configure OIDC**

```sh
$ cd OIDC_Setup_Script/

$$ ls -l
total 20
-rwxr-xr-x 1 Administrator 197121 5458 Apr 23 08:18 delete-oidc-app.sh*
-rw-r--r-- 1 Administrator 197121 1134 Apr 23 08:18 fics.json
-rwxr-xr-x 1 Administrator 197121 7407 Apr 23 11:02 oidc.sh*

# TO configure OIDC
./oidc.sh demo-github-azure-oidc-connection yourrepo/Terraform-Drift-Detection ./fics.json dev

# - `APP_NAME` — the Azure AD application name
# - `REPO` — your GitHub repo in `ORG/REPO` format
# - dev - environment name
```

> [!NOTE]
> *You need to run the above command in bash terminal.*

You will see the following output from command.
  
```sh
./oidc.sh demo-github-azure-oidc-connection yourrepo/Terraform-Drift-Detection ./fics.json dev
==============================================
 Azure OIDC + GitHub Environment Secret Setup
==============================================
App Name    : demo-github-azure-oidc-connection
Repo        : yourrepo/Terraform-Drift-Detection
FICS File   : /c/Users/Administrator/Terraform-Drift-Detection/OIDC_Setup_Script/fics.json
Environment : dev
==============================================

[Azure] Checking login status...
[Azure] Active subscription: [
  "XXXXXXXXXXXXXXXXXXXXXX",
  "DevOpsLearning"
]
Do you want to use the above subscription? (Y/n) Y

[Azure] Fetching Subscription Id...
  SUB_ID: XXXXXXXXXXXXXXXXXXXXXX
[Azure] Fetching Tenant Id...
  TENANT_ID: XXXXXXXXXXXXXXXXXXXXXX

[Azure] Configuring App Registration...
  Creating new AD app: demo-github-azure-oidc-connection...
  Sleeping 30s for app provisioning...
  APP_ID: 4acf655a-0323-41bf-9223-b7ba713832e8

[Azure] Creating Federated Identity Credentials...
  Creating FIC 'prfic' with subject 'repo:yourrepo/Terraform-Drift-Detection:pull_request'...
{
  "@odata.context": "https://graph.microsoft.com/v1.0/$metadata#applications('51977656-b409-49c7-a6d3-a9e7ca168c18')/federatedIdentityCredentials/$entity",
  "audiences": [
    "api://AzureADTokenExchange"
  ],
  "description": "pr",
  "id": "4a8ce028-7e56-4535-822e-ea66ad04f116",
  "issuer": "https://token.actions.githubusercontent.com",
  "name": "prfic",
  "subject": "repo:yourrepo/Terraform-Drift-Detection:pull_request"
}
  Creating FIC 'mainfic' with subject 'repo:yourrepo/Terraform-Drift-Detection:ref:refs/heads/main'...
{
  "@odata.context": "https://graph.microsoft.com/v1.0/$metadata#applications('51977656-b409-49c7-a6d3-a9e7ca168c18')/federatedIdentityCredentials/$entity",
  "audiences": [
    "api://AzureADTokenExchange"
  ],
  "description": "main",
  "id": "cb99e6b5-ede0-4f15-9bf9-66bec06c0232",
  "issuer": "https://token.actions.githubusercontent.com",
  "name": "mainfic",
  "subject": "repo:yourrepo/Terraform-Drift-Detection:ref:refs/heads/main"
}
  Creating FIC 'masterfic' with subject 'repo:yourrepo/Terraform-Drift-Detection:ref:refs/heads/master'...
{
  "@odata.context": "https://graph.microsoft.com/v1.0/$metadata#applications('51977656-b409-49c7-a6d3-a9e7ca168c18')/federatedIdentityCredentials/$entity",
  "audiences": [
    "api://AzureADTokenExchange"
  ],
  "description": "master",
  "id": "8691fb0d-c278-424c-b74a-2513ab45e9e9",
  "issuer": "https://token.actions.githubusercontent.com",
  "name": "masterfic",
  "subject": "repo:yourrepo/Terraform-Drift-Detection:ref:refs/heads/master"
}
  Creating FIC 'envfic-dev' with subject 'repo:yourrepo/Terraform-Drift-Detection:environment:dev'...
{
  "@odata.context": "https://graph.microsoft.com/v1.0/$metadata#applications('51977656-b409-49c7-a6d3-a9e7ca168c18')/federatedIdentityCredentials/$entity",
  "audiences": [
    "api://AzureADTokenExchange"
  ],
  "description": "environment-dev",
  "id": "6c2ffb95-8bc2-45aa-91a8-04bcebbb1259",
  "issuer": "https://token.actions.githubusercontent.com",
  "name": "envfic-dev",
  "subject": "repo:yourrepo/Terraform-Drift-Detection:environment:dev"
}

[GitHub] Logging into GitHub CLI...
github.com
  ✓ Logged in to github.com account yourrepo (keyring)
  - Active account: true
  - Git operations protocol: https
  - Token: gho_************************************
  - Token scopes: 'gist', 'read:org', 'repo', 'workflow'

[GitHub] Creating environment 'dev' in repo 'yourrepo/Terraform-Drift-Detection'...
{
  "id": 14474572144,
  "node_id": "EN_kwDOSF-e-s8AAAADXsBxcA",
  "name": "dev",
  "url": "https://api.github.com/repos/yourrepo/Terraform-Drift-Detection/environments/dev",
  "html_url": "https://github.com/yourrepo/Terraform-Drift-Detection/deployments/activity_log?environments_filter=dev",
  "created_at": "2026-04-23T02:02:36Z",
  "updated_at": "2026-04-23T02:02:36Z",
  "can_admins_bypass": true,
  "protection_rules": [],
  "deployment_branch_policy": null
}
  Environment 'dev' ready.

[GitHub] Setting secrets in environment 'dev'...
✓ Set Actions secret AZURE_CLIENT_ID for yourrepo/Terraform-Drift-Detection
  ✔ AZURE_CLIENT_ID set
✓ Set Actions secret AZURE_SUBSCRIPTION_ID for yourrepo/Terraform-Drift-Detection
  ✔ AZURE_SUBSCRIPTION_ID set
✓ Set Actions secret AZURE_TENANT_ID for yourrepo/Terraform-Drift-Detection
  ✔ AZURE_TENANT_ID set

==============================================
 Setup Complete!
==============================================

The following secrets were created under environment 'dev' in repo 'yourrepo/Terraform-Drift-Detection':

  Secret Name                    Value
  ----------                     -----
  AZURE_CLIENT_ID                XXXXXXXXXXXXXXXXXXXXXX
  AZURE_SUBSCRIPTION_ID          XXXXXXXXXXXXXXXXXXXXXX
  AZURE_TENANT_ID                XXXXXXXXXXXXXXXXXXXXXX

View your App Registration in Azure Portal:
  https://ms.portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/appId/XXXXXXXXXXXXXXXXXXXXXX
```                                                                 
- Verify the `Repository secrets` and you will notice that secerts already been configured.

  - Repo > Settings > Environments >dev 
![alt text](image-18.png)
  
  - Click on environment and you will see secrets
 ![alt text](image-19.png)
---
<details><summary><b>Useful Azure CLI Commands</b></summary><br>

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

**Get the active/default subscription as JSON:**
```bash
az account show --query '{SubscriptionID:id, Name:name}' -o json
```
<br>
</details>

---
**Will create a (Service Principal)**

We need to create a SP (Service Principal) via CLI
Run this once:
```Shell
az ad sp create --id <AZURE_CLIENT_ID>
```
Where <AZURE_CLIENT_ID> is:
```Shell
az ad app list --display-name demo-github-azure-oidc-connection --query "[].appId" -o tsv
```
**To Verify Serice account**
```sh
az ad sp list --filter "appId eq '<AZURE_CLIENT_ID>'" -o table
```


**To delete Serice account**
```sh
az ad sp delete --id <AZURE_CLIENT_ID>
```
**To Verify Serice account**
```sh
az ad sp list --filter "appId eq '<AZURE_CLIENT_ID>'" -o table
```

**Confirm Service Principal Exists**
```sh
az ad sp list --display-name "demo-github-azure-oidc-connection" -o table
```
**Confirm Role Assignment**

```Shell
MSYS_NO_PATHCONV=1 az role assignment list --assignee <SP_OBJECT_ID> --scope /subscriptions/<SUB_ID> -o table

# To get `SP_OBJECT_ID`
az ad app list --display-name demo-github-azure-oidc-connection --query "[].appId" -o tsv

# To get `SUB_ID`
az account list --query '[].{Name:name, ID:id, State:state}' -o table
```
> If the output is **empty**, the role is missing — proceed to Step 1.3.


> [!CAUTION] MSYS_NO_PATHCONV=1 
> we need to use `MSYS_NO_PATHCONV=1` if we are using `gitbash` else you can use powershell without it.

**Assignment Contributor role to Service Principle**
```sh
MSYS_NO_PATHCONV=1 az role assignment create \
  --assignee-object-id <SP_OBJECT_ID> \
  --assignee-principal-type ServicePrincipal \
  --role Contributor \
  --scope /subscriptions/<SUB_ID>

# To get <SP_OBJECT_ID>
az ad sp list \
  --filter "appId eq '4acf655a-0323-41bf-9223-b7ba713832e8'" \
  --query "[0].{SP_ObjectId:id, AppId:appId, DisplayName:displayName}" \
  -o table
```

**Verify Role Assignment**
```Shell
az role assignment list --assignee <SP_OBJECT_ID> --scope /subscriptions/<SUB_ID> -o table
```
---

**Where to find these values in the Azure Portal:**

```
For SUB_ID:
  portal.azure.com
    └── Subscriptions
          └── DevOpsLearning
                └── Overview → Subscription ID ✅

For SP_ID:
  portal.azure.com
    └── Enterprise Applications
          └── Search: demo-github-azure-oidc-connection
                └── Overview → Object ID ✅

      OR

    └── App Registrations → All applications
          └── demo-github-azure-oidc-connection
                └── Overview → Managed application in local directory
                      └── Object ID (SP_ID) ✅
```

**Quick reference table:**

| ID | Portal Location | Field Name |
|----|-----------------|------------|
| `SUB_ID` | Subscriptions → Your Subscription → Overview | Subscription ID |
| `APP_ID` | App Registrations → Your App → Overview | Application (client) ID |
| `SP_ID` | Enterprise Applications → Your App → Overview | Object ID |


---
> [!NOTE]
If failed then you have to give permission manually using GUI

- Go to Subscription > Select your suscription> Access control (IAM) > Add > Add Role assignment >
<img width="1467" height="874" alt="Image" src="https://github.com/user-attachments/assets/cbeb57db-0878-45d1-b223-a8b125c94a80" />

- Select `contributor` role from `Privileged administrator roles` and click `Next`
<img width="1467" height="940" alt="Image" src="https://github.com/user-attachments/assets/80a03547-f8c0-443f-8386-43ffb1259a3f" />

- Click on assign Access to:  Select your service name "`demo-github-azure-oidc-connection`" and click on review and finish.
<img width="1888" height="940" alt="Image" src="https://github.com/user-attachments/assets/8bc959fb-7ed0-4eb5-919f-2a92b4aaefc3" />

---

## Step 2 — Configure Bckend for `tfstate` from Bootstrap folder *(Run Once, Locally)*

```bash
cd bootstrap/
terraform init
terraform apply
```
<img width="1696" height="879" alt="Image" src="https://github.com/user-attachments/assets/17e7626c-dea9-42cb-b439-0c24b0952d51" />

>[!NOTE]
> It will create a *backend storage account* for our pipeline.

### Step 2.1 — Get the Storage Account Key *(Optional)*

If you need to add the storage key to GitHub Secrets:

```bash
terraform output -raw storage_account_key
```

## Assign `Storage Blob Data Contributor` to storage account

- For Push workflow
`Storage Blob Data Contributor`
Because you have `ARM_USE_AZUREAD: true` in my workflow, Terraform authenticates to the storage backend using the Azure AD token (not storage account keys), so `Storage Blob Data Contributor` is mandatory.

The role is assigned on the Storage Account itself (not on the App Registration / OIDC). Think of it this way:

`App Registration / OIDC` = Who you are (Identity)
`Role Assignment on Storage Account` = What you're allowed to do (Permission)


```sh
az account show --query "{subscription:id, tenant:tenantId}" -o table
```
**Step To get storage account details**
```sh
az storage account list \
  --query "[].{Name:name, ResourceGroup:resourceGroup, Location:location}" \
  -o table
```
**Step Get the Storage Account Resource ID**
This is mandatory for RBAC.
```Shell
az storage account show --name <STORAGE NAME> --resource-group <RG Name> --query id -o tsv
```
✅ Example output
```Plain Text
/subscriptions/.../resourceGroups/rg-terraform-state/providers/Microsoft.Storage/storageAccounts/mystorageacct01
```
Save it:

```Shell
STORAGE_SCOPE="/subscriptions/.../storageAccounts/mystorageacct01"
```

**Step 3 — Get the assignee-object-id (Service Principal)**
If you know the App (Client) ID:
```Shell
az ad sp show --id <APP_CLIENT_ID> --query id -o tsv
```
✅ For my case (example)
```Plain Text
Service Principal Object ID:7268b9bc-df91-4ca9-8596-50bcc4cfe56e
```
Save it:
```Plain Text
SP_OBJECT_ID="7268b9bc-df91-4ca9-8596-50bcc4cfe56e"
```


**Step 4 — Assign Storage Blob Data Contributor**

⚠️ IMPORTANT (Git‑Bash USERS)
You MUST disable MSYS path conversion because the scope contains /.

✅ WORKING COMMAND (Git‑Bash safe)
```Shell
MSYS_NO_PATHCONV=1 az role assignment create --assignee-object-id "$SP_OBJECT_ID" --assignee-principal-type ServicePrincipal --role "Storage Blob Data Contributor" --scope "$STORAGE_SCOPE"
```
✅ **Step 5 — Verify the Assignment**
```Shell
MSYS_NO_PATHCONV=1 az role assignment list --assignee-object-id "$SP_OBJECT_ID" --scope "$STORAGE_SCOPE" -o table
```
✅ Expected result
```Plain Text
Storage Blob Data Contributor   /subscriptions/.../storageAccounts/mystorageacct01
```
<details><summary><b>Step-by-Step GUI</b></summary><br>

- Step 1 — Go to your `Storage Account`
Azure Portal → Storage Accounts → <your-backend-storage-account>

- Step 2 — `Open Access Control (IAM)`
Click "Access Control (IAM)" in the left sidebar
![Storage Account left menu → Access Control IAM]

- Step 3 — `Add Role Assignment`
Click "+ Add" → "Add role assignment"
+ Add
 └─ Add role assignment   ← click this

- Step 4 — Search for the Role
On the Role tab, search for:
`Storage Blob Data Contributor`
Select it → click Next

- Step 5 — Assign Access To
On the `Members` tab:
FieldValueAssign access toUser, group, or service principalMembersClick + Select membersSearch boxType `demo-github-azure-oidc-connection`
Select it → click Select → click Next → click `Review + assign`

```sh
Azure Portal
  └── Storage Accounts
        └── <your-backend-storage-account>
              └── Access Control (IAM)              ← LEFT MENU
                    └── + Add → Add role assignment
                          ├── Role tab
                          │     └── Search: "Storage Blob Data Contributor" ✅
                          └── Members tab
                                └── Assign access to: User/group/service principal
                                      └── Select: "demo-github-azure-oidc-connection" ✅
```
</details>
---

**Add Missing Storage Secrets into environment**

Go to:
👉 GitHub → Settings → Environment → Secrets → Actions

Add:
Secret Name	Value Example
BACKEND_AZURE_RESOURCE_GROUP_NAME	`Your Resource Group Name`
BACKEND_AZURE_STORAGE_ACCOUNT_NAME	`tfstate12345`
BACKEND_AZURE_STORAGE_ACCOUNT_CONTAINER_NAME	`tfstate`

or run the following script
```bash
chmod +x 01.create-backend-secrets.sh

# run the following command
./01.create-backend-secrets.sh your-repo/Terraform-Drift-Detection dev
```
Expected Outcome:
```sh
./01.create-backend-secrets.sh your-repo/Terraform-Drift-Detection dev
✅ Repo: your-repo/Terraform-Drift-Detection
✅ Environment: dev
✅ Resource Group: rg-terraform-state
✅ Storage Account: tfstatemyproject002
✅ Container: tfstate
✓ Set Actions secret BACKEND_AZURE_RESOURCE_GROUP_NAME for your-repo/Terraform-Drift-Detection
✓ Set Actions secret BACKEND_AZURE_STORAGE_ACCOUNT_NAME for your-repo/Terraform-Drift-Detection
✓ Set Actions secret BACKEND_AZURE_STORAGE_ACCOUNT_CONTAINER_NAME for your-repo/Terraform-Drift-Detection
🎉 Secrets successfully created in environment 'dev' for repo: your-repo/Terraform-Drift-Detection
```
![alt text](image-20.png)
![alt text](image-21.png)

**To list down all seceret from environment using CLI**
```sh
gh secret list --env dev --repo your-repo/Terraform-Drift-Detection

# Outcomes
NAME                                          UPDATED            
AZURE_CLIENT_ID                               about 1 hour ago
AZURE_SUBSCRIPTION_ID                         about 1 hour ago
AZURE_TENANT_ID                               about 1 hour ago
BACKEND_AZURE_RESOURCE_GROUP_NAME             about 5 minutes ago
BACKEND_AZURE_STORAGE_ACCOUNT_CONTAINER_NAME  about 5 minutes ago
BACKEND_AZURE_STORAGE_ACCOUNT_NAME            about 5 minutes ago
```
<!-- **Nuke Terraform Cache Completely**
bash# Remove all local Terraform cache and state lock files
rm -rf .terraform
rm -f .terraform.lock.hcl
rm -f terraform.tfstate
rm -f terraform.tfstate.backup -->
---

### Step 2.2 — Push Infra Code to GitHub

Once you push to GitHub, Actions will automatically:
- **Run `terraform plan`** on every Pull Request
- **Run `terraform apply`** on every merge to `main`

- Verify pipeline status:

<img width="1696" height="879" alt="Image" src="https://github.com/user-attachments/assets/791e619d-9294-4881-a9db-7f9a3c4c58e9" />

- Verify the infrastructure created by pipeline.

<img width="1696" height="879" alt="Image" src="https://github.com/user-attachments/assets/83d278a6-30a2-4781-b045-c7f05fbc8a3c" />

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

1. Go to → [https://api.slack.com/apps](https://api.slack.com/apps)
2. Click **Create New App** → choose **From scratch**
3. Fill in:
   - **App Name:** `Terraform Drift Bot`
   - **Workspace:** Select your workspace
4. Click **Create App**

**Now enable Incoming Webhooks:**

5. In the App settings page, click **Incoming Webhooks** (left sidebar under **Features**)
6. Toggle **Activate Incoming Webhooks** → `ON`
7. Scroll down and click **Add New Webhook to Workspace**
8. Select the channel → `#terraform-drift-alerts`
9. Click **Allow**

> ⚠️ **Copy the Webhook URL shown — it looks like:**
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

Your repo secrets should now look like this:

```
✅ AZURE_CLIENT_ID
✅ AZURE_SUBSCRIPTION_ID
✅ AZURE_TENANT_ID
✅ SLACK_WEBHOOK_URL    ← NEW
```
<img width="1696" height="879" alt="Image" src="https://github.com/user-attachments/assets/aa42bcb3-36b9-4f11-94e9-0e328a649427" />

---

## Step 5 — Add Manual Approval Before Destroy

### Why This Matters

GitHub Actions supports real approval gates via **Environments**. When a job references an environment:

- ⏸ The workflow **pauses**
- 👤 Approval is required from configured reviewers
- ✅ Only then does `terraform destroy` proceed

This is **auditable**, **native to GitHub**, and the **industry best practice** for production destroy workflows.

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

That's it — nothing else needed in the UI.

---

<!-- ### Step 5.2 — Runtime Execution Flow

Here's what happens when the destroy workflow runs:

```
1. Workflow triggered
2. Terraform destroy plan runs
3. Plan artifact uploaded ✅
4. Workflow PAUSES ⏸
5. GitHub shows: "Waiting for approval: destroy-approval"
6. Reviewer clicks Approve ✅
7. Terraform destroy executes
8. Slack notification sent ✅
``` -->

---

### Step 5.3 — Troubleshooting: OIDC Error on Destroy

> [!NOTE]
> If you hit an authentication error during the destroy stage, the fix is to add a **Federated Credential** for the `destroy-approval` environment in Azure.

**Step A — Go to Azure App Registration:**
- Azure Portal → **Microsoft Entra ID** → **App registrations**
- Select the app referenced by `AZURE_CLIENT_ID`

**Step B — Add a Federated Credential:**
- Click **Federated credentials** → **Add credential**
- Choose scenario: **GitHub Actions deploying Azure resources**
  
<!-- 

**Step C — Fill in the values exactly:**

| Field | Value |
|-------|-------|
| Organization | `YourGitHubUsername` |
| Repository | `Terraform-Drift-Detection` |
| Entity Type | `Environment` |
| Environment Name | `destroy-approval` |
| Credential Name | `github-destroy-approval` |

<img width="1696" height="948" alt="Image" src="https://github.com/user-attachments/assets/deb00be4-dc3a-442e-ba3e-a99f19bea46d" />
<img width="1558" height="765" alt="Image" src="https://github.com/user-attachments/assets/aceb1f27-cda9-447a-b610-a5b3b1b11c60" />
> 👉 Do **NOT** choose Branch  
> 👉 Do **NOT** use wildcards  
> ✅ Save and you're done


**After this fix, the full flow works cleanly:**

```
✅ Azure login
✅ Terraform init
✅ Terraform destroy
✅ Slack notification
```
No pipeline changes needed. No new secrets. No workarounds. -->
---
Slack Notification Alert
<img width="849" height="370" alt="Image" src="https://github.com/user-attachments/assets/a428a938-22fc-4619-817a-52fcbffdb287" />
<img width="849" height="370" alt="Image" src="https://github.com/user-attachments/assets/693f67f1-e548-487a-ae56-da08af4b86ea" />
<img width="996" height="317" alt="Image" src="https://github.com/user-attachments/assets/99af6115-7f80-49be-8272-071304faaf47" />


---
---
---
## Teardown

Once you're done, clean up in this order:

**1. Run the pipeline to destroy your infrastructure**

**2. Destroy the Terraform backend:**
```bash
cd bootstrap/
terraform destroy --auto-approve
```
## GitHub Secrets

- **AZURE_CLIENT_ID**  
  App Registration Application (Client) ID

- **AZURE_TENANT_ID**  
  Entra ID Tenant ID

- **AZURE_SUBSCRIPTION_ID**  
  Azure Subscription ID

**Command to get values**
```sh
echo "CLIENT_ID=$(az ad app list --display-name demo-github-azure-oidc-connection --query '[].appId' -o tsv)"
echo "TENANT_ID=$(az account show --query tenantId -o tsv)"
echo "SUBSCRIPTION_ID=$(az account show --query id -o tsv)"
```

**3. Delete the OIDC app registration:**
- Download the [cleanup script](https://github.com/mrbalraj007/GitHub-Action-Azure_OpenID_Connect-OIDC/blob/main/delete-oidc-app.sh)
- Follow the [OIDC deletion guide](https://github.com/mrbalraj007/GitHub-Action-Azure_OpenID_Connect-OIDC/blob/main/How_to_Configure_OIDC_with_Azure.md)

```sh
# Preview only — no changes made
./delete-oidc-app.sh demo-github-azure-oidc-connection your-repo/Terraform-Drift-Detection dev --dry-run

# Normal delete
./delete-oidc-app.sh demo-github-azure-oidc-connection your-repo/Terraform-Drift-Detection dev
```
---

**Step-by-step fix to rename the branch:**

1️⃣ Check your current branch name
Make sure you’re on the renamed branch:
```Shell
git branch
```
The * should be on the new branch name.

2️⃣ **Push the renamed branch to remote:**

This creates the new branch name on the remote:
```Shell
git push origin -u NEW_BRANCH_NAME
```
Example:
```Shell
git push origin -u feature/new-login
```
Show more lines
The `-u` sets upstream tracking so future pushes work normally.

3️⃣ **Delete the old branch from remote:**

Now remove the old name from the remote:
```Shell
git push origin --delete OLD_BRANCH_NAME
```

Example:
```Shell
git push origin --delete feature/login-old
```

4️⃣ **Refresh in VS Code**
If VS Code still shows the old branch:

Open Command Palette → Git: Fetch
Or run:

```Shell
git fetch --prune
```
This cleans up deleted remote branches.


## 📚 Reference Links

- 🔗 [OIDC Configuration Guide](https://github.com/mrbalraj007/GitHub-Action-Azure_OpenID_Connect-OIDC/blob/main/How_to_Configure_OIDC_with_Azure.md)
- 🔗 [OIDC Setup Script](https://github.com/mrbalraj007/GitHub-Action-Azure_OpenID_Connect-OIDC/blob/main/oidc.sh)
- 🔗 [OIDC Cleanup Script](https://github.com/mrbalraj007/GitHub-Action-Azure_OpenID_Connect-OIDC/blob/main/delete-oidc-app.sh)
- 🔗 [fics.json](https://github.com/mrbalraj007/GitHub-Action-Azure_OpenID_Connect-OIDC/blob/main/fics.json)

---

*Built with 💙 using GitHub Actions + Terraform + Azure OIDC*





<!-- 
# Remove the management lock first (if it exists)
az lock delete \
  --name tfstate-storage-lock \
  --resource-group rg-terraform-state \
  --resource-name tfstatemyproject001 \
  --resource-type Microsoft.Storage/storageAccounts 2>/dev/null || echo "No lock found"

# Delete the storage account
az storage account delete \
  --name tfstatemyproject001 \
  --resource-group rg-terraform-state \
  --yes

# Delete the resource group
az group delete \
  --name rg-terraform-state \
  --yes --no-wait

az group show --name rg-terraform-state 2>/dev/null || echo "RG deleted OK" -->
<!-- 
**Add a new federated credential for repo + environment**
need to add environment and key secret
jobs:
  terraform:
    environment: dev
Azure Federated Credential
repo:your-org/your-repo:environment:dev

On Git Bash (Windows) or any Linux/macOS terminal:
```bash
# Make it executable
chmod +x 02.add-federated-credential
```
# Run it
```sh
./02.add-federated-credential
```
| Step        | Action                                                                 |
|-------------|------------------------------------------------------------------------|
| Pre-flight  | Checks Azure CLI is installed and you're logged in (prompts `az login` if not) |
| Step 1      | Resolves the Object ID of `demo-github-azure-oidc-connection` automatically |
| Step 2      | Idempotency check — skips creation if the credential already exists     |
| Step 3      | Builds the exact OIDC subject: `repo:your-repo/Terraform-Drift-Detection:environment:dev` |
| Step 4      | Creates the federated credential via `az ad app federated-credential create` |
| Step 5      | Lists all credentials on the app so you can visually verify             |
| Step 6      | Prints a reminder of GitHub Secrets needed and their correct values     |


🌍 Step 3 — Create the production Environment in GitHub
This is what creates the manual approval gate before apply runs.

Go to your repo → Settings → Environments
Click New environment
Name it exactly: production (must match what's in the yml)
Click Configure environment
Under Required reviewers, click Add required reviewers
Search for and add yourself (or your team lead)
Click Save protection rules

Repo Settings
└── Environments
    └── production
        └── Required reviewers: [your GitHub username]   ← add yourself here

This means: when a push hits main, the plan job runs automatically. The apply job will then pause and send you an email saying "Review pending". You click Review deployments → Approve and only then does apply execute.

🔀 Step 8 — Test the PR Flow (Optional but Recommended)
This tests the plan-comment-on-PR behaviour:
bash# Create a feature branch
git checkout -b feature/test-workflow

# Make a small change to any .tf file
echo "# test" >> main.tf

git add .
git commit -m "test: trigger PR plan comment"
git push origin feature/test-workflow
Then on GitHub, open a Pull Request from feature/test-workflow → main.
The workflow will run and post a comment directly on the PR like this:
## Terraform Plan Summary 📋
| Detail      | Value                  |
|-------------|------------------------|
| Repository  | your-repo/...        |
| Branch      | feature/test-workflow  |
| ...                                  | -->

<!-- <details><summary>Click to expand full plan output</summary>
...full terraform plan output here...
</details>
Every time you push a new commit to that PR branch, the old comment gets replaced with a fresh one (not duplicated). -->














