#!/usr/bin/env bash
# ----------------------------
# How to run it.
# chmod +x create-backend-secrets.sh
# ./create-backend-secrets.sh my-org/Terraform-Drift-Detection dev
# ----------------------------

set -e

# ----------------------------
# INPUT
# ----------------------------
REPO_NAME="$1"
ENVIRONMENT="$2"

if [[ -z "$REPO_NAME" || -z "$ENVIRONMENT" ]]; then
  echo "❌ Usage: ./create-backend-secrets.sh <repo-name or org/repo> <environment>"
  exit 1
fi

echo "✅ Repo: $REPO_NAME"
echo "✅ Environment: $ENVIRONMENT"

# ----------------------------
# GET AZURE DETAILS
# ----------------------------

RESOURCE_GROUP=$(az group list --query "[0].name" -o tsv)
STORAGE_ACCOUNT=$(az storage account list \
  --resource-group "$RESOURCE_GROUP" \
  --query "[0].name" -o tsv)

ACCOUNT_KEY=$(az storage account keys list \
  --resource-group "$RESOURCE_GROUP" \
  --account-name "$STORAGE_ACCOUNT" \
  --query "[0].value" -o tsv)

CONTAINER_NAME=$(az storage container list \
  --account-name "$STORAGE_ACCOUNT" \
  --account-key "$ACCOUNT_KEY" \
  --query "[0].name" -o tsv)

# ----------------------------
# SANITY CHECK
# ----------------------------

if [[ -z "$RESOURCE_GROUP" || -z "$STORAGE_ACCOUNT" || -z "$CONTAINER_NAME" ]]; then
  echo "❌ Failed to fetch Azure backend values"
  exit 1
fi

echo "✅ Resource Group: $RESOURCE_GROUP"
echo "✅ Storage Account: $STORAGE_ACCOUNT"
echo "✅ Container: $CONTAINER_NAME"

# ----------------------------
# CREATE GITHUB ENVIRONMENT SECRETS
# ----------------------------

gh secret set BACKEND_AZURE_RESOURCE_GROUP_NAME \
  --repo "$REPO_NAME" \
  --env "$ENVIRONMENT" \
  --body "$RESOURCE_GROUP"

gh secret set BACKEND_AZURE_STORAGE_ACCOUNT_NAME \
  --repo "$REPO_NAME" \
  --env "$ENVIRONMENT" \
  --body "$STORAGE_ACCOUNT"

gh secret set BACKEND_AZURE_STORAGE_ACCOUNT_CONTAINER_NAME \
  --repo "$REPO_NAME" \
  --env "$ENVIRONMENT" \
  --body "$CONTAINER_NAME"

echo "🎉 Secrets successfully created in environment '$ENVIRONMENT' for repo: $REPO_NAME"