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