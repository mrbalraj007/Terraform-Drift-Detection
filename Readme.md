Get Subscription ID
```bash
az account show --query id -o tsv
```

Other useful variations
```bash
# Get Subscription ID + Name together
az account show --query '[id,name]' -o tsv
```
# Get all subscriptions in table format

```bash
az account list --query '[].{Name:name, ID:id, State:state}' -o table
```
# Get only the active/default subscription
```bash
az account show --query '{SubscriptionID:id, Name:name}' -o json
```
<!-- Get SP_ID by App Name
```bash
az ad sp list --filter "displayName eq 'demo-github-azure-oidc-connection'" --query "[].id" -o tsv
```
Get SP_ID by App ID
```bash
az ad sp list --filter "appId eq 'ff4d5216-a213-4c7e-8715-e1fa9da58da3'" --query "[].id" -o tsv
``` -->

Get SP_ID + Subscription+ APP_ID together
```bash
az ad sp list --filter "displayName eq 'demo-github-azure-oidc-connection'" \
  --query "[].{SP_ID:id, APP_ID:appId}" -o table && \
  az account show --query "{SUB_ID:id}" -o table
```
## Manually Assign the Role (CLI)

Run the following in Git Bash on your Windows Server 2025:

**Step 1 — Set your known values**

```bash

SP_ID="a778aa7b-f9e2XXXX"  # Finding SUB_ID (Subscription ID)
SUB_ID="2fc598a4-XXXX"     # Finding SP_ID (Service Principal Object ID)
```
```sh
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

| ID | Where to Find | Portal Section |
|----|--------------|----------------|
| `SUB_ID` | Subscriptions → Your subscription → Overview | Subscription ID field |
| `APP_ID` | App Registrations → Your app → Overview | Application (client) ID field |
| `SP_ID` | Enterprise Applications → Your app → Overview | Object ID field |

**Step 2 — Check if a role assignment already exists**

```bash
az role assignment list \
  --assignee $SP_ID \
  --subscription $SUB_ID \
  --query "[].{Role:roleDefinitionName, Scope:scope}" \
  -o table
```

If the output is empty, the role is missing — proceed to Step 3.

**Step 3 — Assign the Contributor role**

```bash
az role assignment create \
  --role contributor \
  --subscription $SUB_ID \
  --assignee-object-id $SP_ID \
  --assignee-principal-type ServicePrincipal
```

## Project Structure
```sh
├── bootstrap/
│   ├── main.tf          # Creates the storage backend resources
│   ├── outputs.tf
│   └── variables.tf
├── backend.tf           # ✅ Already exists (unchanged)
├── main.tf              # ✅ NEW — NSG + Resource Group
├── variables.tf         # ✅ NEW — All configurable values
├── outputs.tf           # ✅ NEW — Useful outputs
├── providers.tf         # ✅ NEW — AzureRM provider
.github/
  workflows/
    ├── terraform.yml          # ✅ CI/CD — Plan on PR, Apply on merge
    └── drift-detection.yml    # ✅ NEW — Nightly drift check + GitHub Issues
```

# Step 1 — Bootstrap the backend (run once, locally)
```sh
cd bootstrap/
terraform init
terraform apply
```
# Step 2 — Get the storage account key and add to GitHub secrets (optional)
```sh
terraform output -raw storage_account_key
```
# Step 3 — Push your infra code to GitHub
# → GitHub Actions will automatically run Plan on PR and Apply on merge to main

<!-- 📋 Overview of What We'll DoStep 1 — Create a Teams Channel
Step 2 — Add Incoming Webhook to that Channel
Step 3 — Copy the Webhook URL
Step 4 — Add Webhook URL to GitHub Secrets
Step 5 — Update drift-detection.yml🔵 Step 1 — Create a Channel in Microsoft Teams1. Open Microsoft Teams
2. Go to your Team (or create one)
3. Click "..." next to the Team name
4. Select "Add channel"
5. Fill in:
      Channel name  : terraform-drift-alerts
      Description   : Terraform drift detection notifications
      Privacy       : Standard
6. Click "Add"🔵 Step 2 — Add Incoming Webhook Connector1. Go to the newly created channel "terraform-drift-alerts"
2. Click "..." next to the channel name
3. Click "Connectors"  (or "Manage channel" → "Connectors")
4. Search for "Incoming Webhook"
5. Click "Add" → "Add" again to confirm
6. Give it a name:  Terraform Drift Bot
7. Optionally upload an icon (Terraform logo)
8. Click "Create"
9. ⚠️  COPY the Webhook URL shown — you won't see it again!
      It looks like:
      https://yourorg.webhook.office.com/webhookb2/xxxx/IncomingWebhook/xxxx
10. Click "Done"🔵 Step 3 — Add Webhook URL to GitHub Secrets1. Go to your GitHub repo → mrbalraj007/Terraform-Drift-Detection
2. Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Add:
      Name  : TEAMS_WEBHOOK_URL
      Value : <paste the webhook URL you copied>
5. Click "Add secret"Your secrets should now look like this:✅ AZURE_CLIENT_ID
✅ AZURE_SUBSCRIPTION_ID
✅ AZURE_TENANT_ID
✅ TEAMS_WEBHOOK_URL   ← NEW -->


Step 1 — Create a Slack Channel
Step 2 — Create a Slack App & Incoming Webhook
Step 3 — Copy the Webhook URL
Step 4 — Add Webhook URL to GitHub Secrets
Step 5 — Update drift-detection.yml

🟢 Step 1 — Create a Slack Channel
1. Open Slack
2. In the left sidebar, click `"+"` next to "`Channels"`
3. Click "`Create a channel`"
4. Fill in:
      Name        : `terraform-drift-alerts`
      Description : `Terraform drift detection notifications from GitHub Actions`
      Visibility  : `Private (recommended)` or Public
5. Click "`Create`"
6. Skip adding members for now (or add your team)

🟢 Step 2 — Create a Slack App & Incoming Webhook
1. Go to → https://api.slack.com/apps
2. Click "`Create New App`"
3. Choose "`From scratch`"
4. Fill in:
      App Name    : `Terraform Drift Bot`
      Workspace   : `Select your workspace`
5. Click "`Create App`"
Now `enable Incoming Webhooks`:
6.  In your App settings page, click "`Incoming Webhooks`" 
    (left sidebar under "`Features`")
7.  Toggle "`Activate Incoming Webhooks`" → `ON`
8.  Scroll down and click "`Add New Webhook to Workspace`"
9.  Select the channel → `#terraform-drift-alerts`
10. Click "`Allow`"
11. ⚠️  COPY the Webhook URL shown — it looks like:
        https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX
12. Keep this page open or save the URL safely

🟢 Step 3 — Add Webhook URL to GitHub Secrets
1. Go to your GitHub repo
      → `yourname/Terraform-Drift-Detection`
2. Click "`Settings`"
3. Click "`Secrets and variables`" → "`Actions`"
4. Click "`New repository secret`"
5. Fill in:
      Name  : `SLACK_WEBHOOK_URL`
      Value : `https://hooks.slack.com/services/xxxx/xxxx/xxxx`
6. Click "`Add secret`"

Your secrets should now look like this:
- ✅ AZURE_CLIENT_ID
- ✅ AZURE_SUBSCRIPTION_ID
- ✅ AZURE_TENANT_ID
- ✅ SLACK_WEBHOOK_URL    ← NEW

<!-- 
Step‑by‑step: Create a Slack Incoming Webhook
Step 2.1: Create a Slack App

Go to:
👉 https://api.slack.com/apps
Click Create New App
Choose From scratch
App name:
Terraform Drift Detector


Choose your Slack workspace
Click Create App


Step 2.2: Enable Incoming Webhooks

Inside your new Slack app:

Go to Incoming Webhooks


Toggle Activate Incoming Webhooks → ✅ ON
Click Add New Webhook to Workspace
Choose the Slack channel where alerts should go (e.g. #terraform-alerts)
Click Allow

✅ Slack will generate a Webhook URL, for example:
https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXX

⚠️ This is a secret. Never commit it to Git.

3. Step‑by‑step: Add Slack webhook to GitHub Actions
Step 3.1: Store the webhook securely in GitHub

Go to your GitHub repository
Settings → Secrets and variables → Actions
Click New repository secret
Add:

Name:
SLACK_WEBHOOK_URL


Value:
(Paste the Slack webhook URL)


Save ✅ -->

✅ 1. How Manual Approval Works in GitHub Actions
GitHub supports real approval gates via Environments.
✅ When a job references an environment:

Workflow pauses
Approval is required from configured reviewers
Only then does destroy proceed

This is:

Auditable
Native
Industry best practice


✅ 2. One‑Time Setup in GitHub UI (MANDATORY)
Step A — Create an Environment

Repo → Settings
Environments
Click New environment
Name it exactly:
destroy-approval


Click Configure environment


Step B — Add Required Reviewers

Enable ✅ Required reviewers
Add:

Yourself
OR platform team


Save

✅ Done. Nothing else needed.




- Reference Link
- Youtube
- [ Microsoft Teams Connector](https://www.youtube.com/watch?v=sX3nliVH8e4&list=PLJcpyd04zn7q-TF17zwoc3IZNUB8skKD2&index=5)
