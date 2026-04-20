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

Before anything else, get these three things in place:
- [Terraform CLI](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) must be installed
- Clone the [Repo: Terraform-Drift-Detection](https://github.com/mrbalraj007/Terraform-Drift-Detection.git)
- 🔗 Configure an [OIDC connection](https://github.com/mrbalraj007/GitHub-Action-Azure_OpenID_Connect-OIDC/blob/main/How_to_Configure_OIDC_with_Azure.md) for passwordless Azure authentication
- 📥 Download the [OIDC setup script](https://github.com/mrbalraj007/GitHub-Action-Azure_OpenID_Connect-OIDC/blob/main/oidc.sh)
- 📥 Download [fics.json](https://github.com/mrbalraj007/GitHub-Action-Azure_OpenID_Connect-OIDC/blob/main/fics.json)

- **Command to configure OIDC**
```sh
./oidc.sh demo-github-azure-oidc-connection singhmr_xxx/Terraform-Drift-Detection

# - `APP_NAME` — the Azure AD application name
# - `REPO` — your GitHub repo in `ORG/REPO` format

```
> [!CAUTION]
*You need to run the above command `twice a time` in terminal.*

> When you run the above command then it will ask you the following thing
  
      ```sh
      Logging into GitHub CLI...
      ? Where do you use GitHub? GitHub.com                                                                                                                                                                                
      ? What is your preferred protocol for Git operations on this host? HTTPS                                                                                                                                                  
      ? Authenticate Git with your GitHub credentials? Yes                                                                                                                                                                      
      ? How would you like to authenticate GitHub CLI? Login with a web browser                                                                                                                                                 
                                                                                                                                                                                    ! First copy your one-time code: 25EE-C65B                                                                                                                                                                                
      Press Enter to open https://github.com/login/device in your browser...                                                                              ```                                                                      
![alt text](image.png)
![alt text](image-1.png)

It will looks like that
![alt text](image-2.png)

- Verify the `Repository secrets` and you will notice that secerts already been configured.

  - Repo > Settings >secrets and variables >Actions 
  
![alt text](image-3.png)

### Useful Azure CLI Commands

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

<!-- **Get SP_ID, APP_ID, and SUB_ID in one shot:**
```bash
az ad sp list --filter "displayName eq 'demo-github-azure-oidc-connection'" \
  --query "[].{SP_ID:id, APP_ID:appId}" -o table && \
  az account show --query "{SUB_ID:id}" -o table
``` -->

**Get Object ID — CLI & GUI**
- Via CLI

**By App Name**
```bash
az ad sp list --filter "displayName eq 'demo-github-azure-oidc-connection'" \
  --query "[].{ObjectID:id, AppID:appId, Name:displayName}" \
  -o table
```


**Via GUI (Azure Portal)**
```sh
portal.azure.com
  └── Search → "Enterprise Applications"
        └── Search: demo-github-azure-oidc-connection
              └── Overview
                    └── Object ID  ← Copy this ✅
```                    
---

## Step 1 — Manually Assign the Contributor Role (CLI)

Run the following steps in Git Bash (or any terminal with Azure CLI installed).

### Step 1.1 — Set Your Known Values

```bash
SP_ID="a778aa7b-f9e2XXXX"  # Finding SUB_ID (Subscription ID)
SUB_ID="2fc598a4-XXXX"     # Finding SP_ID (Service Principal Object ID)
```

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

### Step 1.2 — Check if a Role Assignment Already Exists

```bash
az role assignment list \
  --assignee $SP_ID \
  --subscription $SUB_ID \
  --query "[].{Role:roleDefinitionName, Scope:scope}" \
  -o table
```

> If the output is **empty**, the role is missing — proceed to Step 1.3.

---

### Step 1.3 — Assign the Contributor Role

```bash
az role assignment create \
  --role contributor \
  --subscription $SUB_ID \
  --assignee-object-id $SP_ID \
  --assignee-principal-type ServicePrincipal
```
> [!NOTE]
If failed then you have to give permission manually using GUI

- Go to Subscription > Select your suscription> Access control (IAM) > Add > Add Role assignment >
![alt text](image-4.png)

- Select `contributor` role from `Privileged administrator roles` and click `Next`
![alt text](image-5.png)

- Click on assign Access to:  Select your service name "`demo-github-azure-oidc-connection`" and click on review and finish.
![alt text](image-6.png)

---

### Step 1.4 — Quick Verification Command
```bash
az role assignment list \
  --assignee $SP_ID \
  --subscription $SUB_ID \
  --query "[].{Role:roleDefinitionName, Scope:scope}" \
  -o table
```
---

## Project Structure

```
├── bootstrap/
│   ├── main.tf          # Creates the storage backend resources
│   ├── outputs.tf
│   └── variables.tf
├── backend.tf           # ✅ Already exists (unchanged)
├── main.tf              # ✅ NEW — NSG + Resource Group
├── variables.tf         # ✅ NEW — All configurable values
├── outputs.tf           # ✅ NEW — Useful outputs
├── providers.tf         # ✅ NEW — AzureRM provider
└── .github/
    └── workflows/
        ├── terraform_CI_CD_JOB.yml                # ✅ CI/CD — Plan on PR, Apply on merge
        ├── Terraform - Format and Validate.yml    # ✅ Push and Pull
│       ├── destroy_resources.yml                  # ✅ To destroy the environment/resources 
│       └── drift-detection.yml                    # ✅ NEW — Nightly drift check + GitHub Issues
        └── Dummy_Azure_login_validate.yml         # ✅ For dummy azue login testing
        └── TBT-With_MSTeam_drift-detection.ps1    # ✅ Will test it when MS Team issue fixed
```

---

## Step 2 — Bootstrap the Backend *(Run Once, Locally)*

```bash
cd bootstrap/
terraform init
terraform apply
```
![alt text](image-7.png)

>[!NOTE]
> It will create a *backend storage account* for our pipeline.

### Step 2.1 — Get the Storage Account Key *(Optional)*

If you need to add the storage key to GitHub Secrets:

```bash
terraform output -raw storage_account_key
```

### Step 2.2 — Push Infra Code to GitHub

Once you push to GitHub, Actions will automatically:
- **Run `terraform plan`** on every Pull Request
- **Run `terraform apply`** on every merge to `main`

- Verify pipeline status:
![alt text](image-8.png)

- Verify the infrastructure created by pipeline.
   ![alt text](image-9.png)

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
![alt text](image-10.png)

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
3. Name it **exactly**: `destroy-approval`
4. Click **Configure environment**

**Add Required Reviewers:**

1. Enable ✅ **Required reviewers**
2. Add yourself and/or your platform team
3. Click **Save**

That's it — nothing else needed in the UI.
![alt text](image-11.png)

---

### Step 5.2 — Runtime Execution Flow

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
```

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
![alt text](image-12.png)
**Step C — Fill in the values exactly:**

| Field | Value |
|-------|-------|
| Organization | `YourGitHubUsername` |
| Repository | `Terraform-Drift-Detection` |
| Entity Type | `Environment` |
| Environment Name | `destroy-approval` |
| Credential Name | `github-destroy-approval` |

![alt text](image-13.png)
![alt text](image-14.png)
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
No pipeline changes needed. No new secrets. No workarounds.
---
Slack Notification Alert
![alt text](image-15.png)

![alt text](image-16.png)

![alt text](image-17.png)


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

**3. Delete the OIDC app registration:**
- Download the [cleanup script](https://github.com/mrbalraj007/GitHub-Action-Azure_OpenID_Connect-OIDC/blob/main/delete-oidc-app.sh)
- Follow the [OIDC deletion guide](https://github.com/mrbalraj007/GitHub-Action-Azure_OpenID_Connect-OIDC/blob/main/How_to_Configure_OIDC_with_Azure.md)

```sh
# Dry run
./delete-oidc-app.sh demo-github-azure-oidc-connection singhmr_xxx/Terraform-Drift-Detection --dry-run

# Delete OIDC
./delete-oidc-app.sh demo-github-azure-oidc-connection singhmr_xxx/Terraform-Drift-Detection
```
---

## 📚 Reference Links

- 🔗 [OIDC Configuration Guide](https://github.com/mrbalraj007/GitHub-Action-Azure_OpenID_Connect-OIDC/blob/main/How_to_Configure_OIDC_with_Azure.md)
- 🔗 [OIDC Setup Script](https://github.com/mrbalraj007/GitHub-Action-Azure_OpenID_Connect-OIDC/blob/main/oidc.sh)
- 🔗 [OIDC Cleanup Script](https://github.com/mrbalraj007/GitHub-Action-Azure_OpenID_Connect-OIDC/blob/main/delete-oidc-app.sh)
- 🔗 [fics.json](https://github.com/mrbalraj007/GitHub-Action-Azure_OpenID_Connect-OIDC/blob/main/fics.json)

---

*Built with 💙 using GitHub Actions + Terraform + Azure OIDC*



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
| Repository  | mrbalraj007/...        |
| Branch      | feature/test-workflow  |
| ...                                  |

<details><summary>Click to expand full plan output</summary>
...full terraform plan output here...
</details>
Every time you push a new commit to that PR branch, the old comment gets replaced with a fresh one (not duplicated).


Fix A — Azure Portal (do this now, 2 minutes)
Your SP needs the storage data-plane role. Without this, terraform init will always 403 on any PR or push:
Storage Accounts → <your backend storage account>
  → Access Control (IAM)
    → Add role assignment
      → Role:   Storage Blob Data Contributor
      → Member: demo-github-azure-oidc-connection
Fix B — The yml change (already done above)
The one critical line added to the "Commit fmt fixes" step:
yaml# BEFORE (broken on PRs):
- name: Commit Terraform fmt fixes
  run: |
    git push   ← fails: detached HEAD on pull_request events

# AFTER (fixed):
- name: Commit Terraform fmt fixes
  if: github.event_name == 'push'    ← skips entirely on PRs
  run: |
    git push
On a PR the fmt still runs and fixes files on the runner — it just doesn't try to commit back, because on a PR the runner is not on any branch and cannot push. The plan still executes against the corrected files.


#https://claude.ai/chat/c0089ec3-8e90-451e-9468-0c5af04c7f65