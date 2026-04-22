#!/bin/bash
set -euo pipefail

# Open in DevContainer or...

    # Install Azure CLI- https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
    # Install GitHub CLI - https://cli.github.com/
    # Install JQ - https://stedolan.github.io/jq/download/

# Usage:
# ./oidc.sh {APP_NAME} {ORG|USER/REPO} {FICS_FILE} [ENVIRONMENT]
# ./oidc.sh demo-github-azure-oidc-connection mrbalraj007/Terraform-Drift-Detection ./fics.json dev

IS_CODESPACE=${CODESPACES:-"false"}
if $IS_CODESPACE == "true"
then
    echo "This script doesn't work in GitHub Codespaces.  See this issue for updates. https://github.com/Azure/azure-cli/issues/21025"
    exit 0
fi

APP_NAME=$1
export REPO=$2
FICS_FILE=$(realpath "$3")   # FIX 1: Resolve absolute path — prevents Git Bash from mangling relative paths in subshells
export GITHUB_ENV=${4:-"dev"}  # Exported so envsubst substitutes ${GITHUB_ENV} in fics.json

echo "=============================================="
echo " Azure OIDC + GitHub Environment Secret Setup"
echo "=============================================="
echo "App Name    : $APP_NAME"
echo "Repo        : $REPO"
echo "FICS File   : $FICS_FILE"
echo "Environment : $GITHUB_ENV"
echo "=============================================="
echo ""

# -----------------------------------------------
# Azure Login Check
# -----------------------------------------------
echo "[Azure] Checking login status..."
EXPIRED_TOKEN=$(az ad signed-in-user show --query 'id' -o tsv 2>/dev/null || true)

if [[ -z "$EXPIRED_TOKEN" ]]
then
    az login -o none
fi

ACCOUNT=$(az account show --query '[id,name]')
echo "[Azure] Active subscription: $ACCOUNT"

read -r -p "Do you want to use the above subscription? (Y/n) " response
response=${response:-Y}
case "$response" in
    [yY][eE][sS]|[yY])
        ;;
    *)
        echo "Use the \`az account set -s\` command to set the subscription you'd like to use and re-run this script."
        exit 0
        ;;
esac

# -----------------------------------------------
# Gather Azure Details
# -----------------------------------------------
echo ""
echo "[Azure] Fetching Subscription Id..."
SUB_ID=$(az account show --query id -o tsv)
echo "  SUB_ID: $SUB_ID"

echo "[Azure] Fetching Tenant Id..."
TENANT_ID=$(az account show --query tenantId -o tsv)
echo "  TENANT_ID: $TENANT_ID"

# -----------------------------------------------
# App Registration
# -----------------------------------------------
echo ""
echo "[Azure] Configuring App Registration..."

APP_ID=$(az ad app list --filter "displayName eq '$APP_NAME'" --query [].appId -o tsv)

if [[ -z "$APP_ID" ]]
then
    echo "  Creating new AD app: $APP_NAME..."
    APP_ID=$(az ad app create --display-name "${APP_NAME}" --query appId -o tsv)
    echo "  Sleeping 30s for app provisioning..."
    sleep 30s
else
    echo "  Existing AD app found."
fi

echo "  APP_ID: $APP_ID"

# -----------------------------------------------
# Service Principal
# -----------------------------------------------
# echo ""
# echo "[Azure] Configuring Service Principal..."

# SP_ID=$(az ad sp list --filter "appId eq '$APP_ID'" --query [].id -o tsv)

# if [[ -z "$SP_ID" ]]
# then
#     echo "  Creating Service Principal..."
#     SP_ID=$(az ad sp create --id "$APP_ID" --query id -o tsv)

#     echo "  Sleeping 30s for SP provisioning..."
#     sleep 30s

#     echo "  Creating Contributor role assignment..."
#     az role assignment create \
#         --role contributor \
#         --scope "/subscriptions/${SUB_ID}" \
#         --assignee-object-id "$SP_ID" \
#         --assignee-principal-type ServicePrincipal
#     sleep 30s
# else
#     echo "  Existing Service Principal found."
# fi

# echo "  SP_ID: $SP_ID"

# -----------------------------------------------
# Federated Identity Credentials
# -----------------------------------------------
echo ""
echo "[Azure] Creating Federated Identity Credentials..."

for FIC in $(envsubst < "$FICS_FILE" | jq -c '.[]'); do
    SUBJECT=$(jq -r '.subject' <<< "$FIC")
    FIC_NAME=$(jq -r '.name' <<< "$FIC")

    # Check if FIC already exists
    EXISTING_FIC=$(az ad app federated-credential list --id "$APP_ID" \
        --query "[?name=='${FIC_NAME}'].name" -o tsv 2>/dev/null || true)

    if [[ -n "$EXISTING_FIC" ]]; then
        echo "  FIC '${FIC_NAME}' already exists — skipping."
    else
        echo "  Creating FIC '${FIC_NAME}' with subject '${SUBJECT}'..."
        az ad app federated-credential create --id "$APP_ID" --parameters "${FIC}" || true
    fi
done

# -----------------------------------------------
# GitHub CLI Login
# -----------------------------------------------
echo ""
echo "[GitHub] Logging into GitHub CLI..."
gh auth status 2>/dev/null || gh auth login

# -----------------------------------------------
# Create GitHub Environment
# NOTE: Git Bash on Windows rewrites any argument starting with "/" into a
#       Windows filesystem path before the process even launches, so
#       MSYS_NO_PATHCONV=1 as an inline prefix is too late.
#       Solution: store the path in a variable WITHOUT a leading slash —
#       Git Bash only converts slash-prefixed string literals, not variables.
# -----------------------------------------------
echo ""
echo "[GitHub] Creating environment '${GITHUB_ENV}' in repo '${REPO}'..."

GH_API_PATH="repos/${REPO}/environments/${GITHUB_ENV}"
gh api \
    --method PUT \
    -H "Accept: application/vnd.github+json" \
    "$GH_API_PATH" \
    --input - <<< '{}' \
    && echo "  Environment '${GITHUB_ENV}' ready." \
    || { echo "  ERROR: Failed to create environment '${GITHUB_ENV}'. Check repo permissions."; exit 1; }

# -----------------------------------------------
# Set GitHub Environment-Level Secrets
# -----------------------------------------------
echo ""
echo "[GitHub] Setting secrets in environment '${GITHUB_ENV}'..."

gh secret set AZURE_CLIENT_ID \
    --body "${APP_ID}" \
    --env "${GITHUB_ENV}" \
    --repo "${REPO}"
echo "  ✔ AZURE_CLIENT_ID set"

gh secret set AZURE_SUBSCRIPTION_ID \
    --body "${SUB_ID}" \
    --env "${GITHUB_ENV}" \
    --repo "${REPO}"
echo "  ✔ AZURE_SUBSCRIPTION_ID set"

gh secret set AZURE_TENANT_ID \
    --body "${TENANT_ID}" \
    --env "${GITHUB_ENV}" \
    --repo "${REPO}"
echo "  ✔ AZURE_TENANT_ID set"

# -----------------------------------------------
# Summary
# -----------------------------------------------
echo ""
echo "=============================================="
echo " Setup Complete!"
echo "=============================================="
echo ""
echo "The following secrets were created under environment '${GITHUB_ENV}' in repo '${REPO}':"
echo ""
printf "  %-30s %s\n" "Secret Name" "Value"
printf "  %-30s %s\n" "----------" "-----"
printf "  %-30s %s\n" "AZURE_CLIENT_ID"       "$APP_ID"
printf "  %-30s %s\n" "AZURE_SUBSCRIPTION_ID" "$SUB_ID"
printf "  %-30s %s\n" "AZURE_TENANT_ID"       "$TENANT_ID"
echo ""
echo "View your App Registration in Azure Portal:"
echo "  https://ms.portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/appId/${APP_ID}"
echo ""
echo "View your GitHub Environment secrets:"
echo "  https://github.com/${REPO}/settings/environments"
echo ""