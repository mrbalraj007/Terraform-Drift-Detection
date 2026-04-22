#!/usr/bin/env bash
# =============================================================================
# Script  : add-federated-credential.sh
# Purpose : Add a Federated Identity Credential to an existing Azure App
#           Registration for GitHub Actions OIDC (environment-scoped)
# Repo    : mrbalraj007/Terraform-Drift-Detection
# Author  : Mr Singh
# =============================================================================

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURATION — Edit these values if needed
# ─────────────────────────────────────────────────────────────────────────────
APP_NAME="demo-github-azure-oidc-connection"
GITHUB_ORG="mrbalraj007"
GITHUB_REPO="Terraform-Drift-Detection"
GITHUB_ENVIRONMENT="dev"
CREDENTIAL_NAME="terraform-drift-detection-env-dev"

# ─────────────────────────────────────────────────────────────────────────────
# COLOURS
# ─────────────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Colour

# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ─────────────────────────────────────────────────────────────────────────────
# PRE-FLIGHT: Check Azure CLI is installed and logged in
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo "  Azure OIDC Federated Credential Setup"
echo "  Repo : ${GITHUB_ORG}/${GITHUB_REPO}"
echo "  Env  : ${GITHUB_ENVIRONMENT}"
echo "============================================================"
echo ""

info "Checking Azure CLI installation..."
if ! command -v az &>/dev/null; then
  error "Azure CLI not found. Install it from https://aka.ms/installazurecli"
fi
success "Azure CLI found: $(az version --query '"azure-cli"' -o tsv)"

info "Checking Azure login status..."
ACCOUNT=$(az account show --query "user.name" -o tsv 2>/dev/null || true)
if [[ -z "$ACCOUNT" ]]; then
  warn "Not logged in. Running 'az login'..."
  az login
fi
success "Logged in as: $(az account show --query 'user.name' -o tsv)"
info   "Subscription : $(az account show --query 'name' -o tsv)"
info   "Tenant       : $(az account show --query 'tenantId' -o tsv)"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 1 — Resolve the App Registration's Object ID (NOT Application/Client ID)
# ─────────────────────────────────────────────────────────────────────────────
echo ""
info "Resolving App Registration: '${APP_NAME}'..."

APP_OBJECT_ID=$(az ad app list \
  --display-name "$APP_NAME" \
  --query "[0].id" \
  -o tsv 2>/dev/null || true)

if [[ -z "$APP_OBJECT_ID" || "$APP_OBJECT_ID" == "None" ]]; then
  error "App Registration '${APP_NAME}' not found. Verify the display name is correct."
fi

APP_CLIENT_ID=$(az ad app list \
  --display-name "$APP_NAME" \
  --query "[0].appId" \
  -o tsv)

success "Found App Registration"
info   "  Display Name : ${APP_NAME}"
info   "  Object ID    : ${APP_OBJECT_ID}"
info   "  Client ID    : ${APP_CLIENT_ID}"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 2 — Check if this federated credential already exists
# ─────────────────────────────────────────────────────────────────────────────
echo ""
info "Checking for existing federated credential '${CREDENTIAL_NAME}'..."

EXISTING=$(az ad app federated-credential list \
  --id "$APP_OBJECT_ID" \
  --query "[?name=='${CREDENTIAL_NAME}'].name" \
  -o tsv 2>/dev/null || true)

if [[ -n "$EXISTING" ]]; then
  warn "Federated credential '${CREDENTIAL_NAME}' already exists. Skipping creation."
  echo ""
  info "Existing credentials on this App Registration:"
  az ad app federated-credential list \
    --id "$APP_OBJECT_ID" \
    --query "[].{Name:name, Subject:subject, Issuer:issuer}" \
    -o table
  echo ""
  success "No changes made. Your OIDC setup is already in place."
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 3 — Build the OIDC subject claim
#   Format for environment-scoped: repo:<org>/<repo>:environment:<env>
# ─────────────────────────────────────────────────────────────────────────────
SUBJECT="repo:${GITHUB_ORG}/${GITHUB_REPO}:environment:${GITHUB_ENVIRONMENT}"
ISSUER="https://token.actions.githubusercontent.com"
AUDIENCE="api://AzureADTokenExchange"

echo ""
info "Federated credential details to be created:"
printf "  %-20s : %s\n" "Name"        "$CREDENTIAL_NAME"
printf "  %-20s : %s\n" "Issuer"      "$ISSUER"
printf "  %-20s : %s\n" "Subject"     "$SUBJECT"
printf "  %-20s : %s\n" "Audience"    "$AUDIENCE"
printf "  %-20s : %s\n" "Description" "GitHub Actions OIDC for ${GITHUB_REPO} (environment: ${GITHUB_ENVIRONMENT})"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# STEP 4 — Create the federated credential
# ─────────────────────────────────────────────────────────────────────────────
info "Creating federated credential..."

az ad app federated-credential create \
  --id "$APP_OBJECT_ID" \
  --parameters "{
    \"name\": \"${CREDENTIAL_NAME}\",
    \"issuer\": \"${ISSUER}\",
    \"subject\": \"${SUBJECT}\",
    \"audiences\": [\"${AUDIENCE}\"],
    \"description\": \"GitHub Actions OIDC for ${GITHUB_REPO} (environment: ${GITHUB_ENVIRONMENT})\"
  }"

success "Federated credential created successfully!"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 5 — Verify: list all federated credentials on this app
# ─────────────────────────────────────────────────────────────────────────────
echo ""
info "Verifying — all federated credentials on '${APP_NAME}':"
az ad app federated-credential list \
  --id "$APP_OBJECT_ID" \
  --query "[].{Name:name, Subject:subject}" \
  -o table

# ─────────────────────────────────────────────────────────────────────────────
# STEP 6 — Print GitHub Secrets reminder
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
success "Setup Complete!"
echo "============================================================"
echo ""
info "Ensure the following GitHub Secrets are set on:"
info "  https://github.com/${GITHUB_ORG}/${GITHUB_REPO}/settings/secrets/actions"
echo ""
printf "  %-30s : %s\n" "AZURE_CLIENT_ID"      "$APP_CLIENT_ID"
printf "  %-30s : %s\n" "AZURE_TENANT_ID"      "$(az account show --query 'tenantId' -o tsv)"
printf "  %-30s : %s\n" "AZURE_SUBSCRIPTION_ID" "$(az account show --query 'id' -o tsv)"
echo ""
info "Also ensure a GitHub Environment named '${GITHUB_ENVIRONMENT}' exists at:"
info "  https://github.com/${GITHUB_ORG}/${GITHUB_REPO}/settings/environments"
echo ""