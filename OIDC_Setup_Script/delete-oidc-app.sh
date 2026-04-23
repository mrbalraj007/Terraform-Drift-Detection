#!/bin/bash
set -euo pipefail

# Usage:
# ./delete-oidc-app.sh {APP_NAME} {ORG/REPO} [ENVIRONMENT] [--dry-run]
# ./delete-oidc-app.sh demo-github-azure-oidc-connection mrbalraj007/Terraform-Drift-Detection dev
# ./delete-oidc-app.sh demo-github-azure-oidc-connection mrbalraj007/Terraform-Drift-Detection dev --dry-run

APP_NAME=$1
REPO=$2
GITHUB_ENV=${3:-"dev"}     # Default environment is "dev"
DRY_RUN=${4:-""}

IS_DRY_RUN=false
if [[ "$DRY_RUN" == "--dry-run" ]]; then
    IS_DRY_RUN=true
    echo "🔍 DRY RUN MODE ENABLED — No changes will be made."
fi

run_or_echo() {
    if $IS_DRY_RUN; then
        echo "  [DRY RUN] $*"
    else
        eval "$@"
    fi
}

echo "=============================================="
echo " Azure OIDC + GitHub Environment Cleanup"
echo "=============================================="
echo "App Name    : $APP_NAME"
echo "Repo        : $REPO"
echo "Environment : $GITHUB_ENV"
echo "Dry Run     : $IS_DRY_RUN"
echo "=============================================="
echo ""

# -----------------------------------------------
# Azure Login Check
# -----------------------------------------------
echo "[Azure] Checking login status..."
EXPIRED_TOKEN=$(az ad signed-in-user show --query 'id' -o tsv 2>/dev/null || true)

if [[ -z "$EXPIRED_TOKEN" ]]; then
    az login -o none
fi

echo "[Azure] Fetching Subscription ID..."
SUB_ID=$(az account show --query id -o tsv)
echo "  SUB_ID: $SUB_ID"

# -----------------------------------------------
# App Registration Lookup
# -----------------------------------------------
echo ""
echo "[Azure] Looking up AD application '$APP_NAME'..."
APP_ID=$(az ad app list --filter "displayName eq '$APP_NAME'" --query "[0].appId" -o tsv)

if [[ -z "$APP_ID" ]]; then
    echo "  ❌ No application found with name '$APP_NAME'. Nothing to delete."
    exit 0
fi

echo "  APP_ID: $APP_ID"

# -----------------------------------------------
# Federated Identity Credentials
# -----------------------------------------------
echo ""
echo "[Azure] Fetching Federated Identity Credentials..."
FICS=$(az ad app federated-credential list --id "$APP_ID" --query "[].id" -o tsv 2>/dev/null || true)

if [[ -n "$FICS" ]]; then
    while IFS= read -r FIC_ID; do
        echo "  Deleting FIC: $FIC_ID"
        run_or_echo "az ad app federated-credential delete --id $APP_ID --federated-credential-id $FIC_ID"
    done <<< "$FICS"
else
    echo "  No FICs found — skipping."
fi

# -----------------------------------------------
# Service Principal + Role Assignments
# -----------------------------------------------
echo ""
echo "[Azure] Looking up Service Principal..."
SP_ID=$(az ad sp list --filter "appId eq '$APP_ID'" --query "[0].id" -o tsv 2>/dev/null || true)

if [[ -n "$SP_ID" ]]; then
    echo "  SP_ID: $SP_ID"
    echo "  Deleting Service Principal (role assignments auto-removed)..."
    run_or_echo "az ad sp delete --id $SP_ID"
else
    echo "  No Service Principal found — skipping."
fi

# -----------------------------------------------
# AD Application
# -----------------------------------------------
echo ""
echo "[Azure] Deleting AD Application..."
run_or_echo "az ad app delete --id $APP_ID"
echo "  ✔ AD Application deleted (or simulated)."

# -----------------------------------------------
# GitHub CLI Login
# -----------------------------------------------
echo ""
echo "[GitHub] Checking GitHub CLI login..."
gh auth status 2>/dev/null || gh auth login

# -----------------------------------------------
# Delete Environment-Level Secrets
# -----------------------------------------------
echo ""
echo "[GitHub] Deleting secrets from environment '${GITHUB_ENV}' in repo '${REPO}'..."

for SECRET in AZURE_CLIENT_ID AZURE_SUBSCRIPTION_ID AZURE_TENANT_ID; do
    if $IS_DRY_RUN; then
        echo "  [DRY RUN] gh secret delete $SECRET --env ${GITHUB_ENV} --repo ${REPO}"
    else
        gh secret delete "$SECRET" --env "${GITHUB_ENV}" --repo "${REPO}" 2>/dev/null \
            && echo "  ✔ $SECRET deleted" \
            || echo "  ⚠ $SECRET not found — skipping."
    fi
done

# -----------------------------------------------
# Delete GitHub Environment
# -----------------------------------------------
echo ""
echo "[GitHub] Deleting environment '${GITHUB_ENV}' from repo '${REPO}'..."

GH_API_PATH="repos/${REPO}/environments/${GITHUB_ENV}"
if $IS_DRY_RUN; then
    echo "  [DRY RUN] gh api --method DELETE $GH_API_PATH"
else
    gh api \
        --method DELETE \
        -H "Accept: application/vnd.github+json" \
        "$GH_API_PATH" 2>/dev/null \
        && echo "  ✔ Environment '${GITHUB_ENV}' deleted." \
        || echo "  ⚠ Environment '${GITHUB_ENV}' not found or could not be deleted — skipping."
fi

# -----------------------------------------------
# Summary
# -----------------------------------------------
echo ""
echo "=============================================="
echo " Cleanup Complete!"
echo "=============================================="
if $IS_DRY_RUN; then
    echo "  ⚠ Dry-run mode was active — no changes were made."
else
    echo "  ✔ Azure AD App     : $APP_NAME ($APP_ID) deleted"
    echo "  ✔ GitHub Secrets   : removed from environment '${GITHUB_ENV}'"
    echo "  ✔ GitHub Env       : '${GITHUB_ENV}' deleted from ${REPO}"
fi
echo ""