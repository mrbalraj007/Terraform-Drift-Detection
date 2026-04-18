terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "azurerm" {
  features {}
}

# --- Resource Group for Terraform State ---
resource "azurerm_resource_group" "tfstate" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Purpose   = "Terraform State Backend"
    ManagedBy = "Terraform Bootstrap"
  }
}

# --- Storage Account (equivalent to S3 bucket) ---
resource "azurerm_storage_account" "tfstate" {
  name                            = var.storage_account_name # must be globally unique, lowercase, 3-24 chars
  resource_group_name             = azurerm_resource_group.tfstate.name
  location                        = azurerm_resource_group.tfstate.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS" # Geo-redundant for safety
  allow_nested_items_to_be_public = false # Block all public access

  blob_properties {
    versioning_enabled = true # Keeps history of state files

    delete_retention_policy {
      days = 30 # Soft delete for 30 days
    }
  }

  tags = {
    Purpose   = "Terraform State Backend"
    ManagedBy = "Terraform Bootstrap"
  }
}

# --- Blob Container (equivalent to S3 prefix/folder) ---
resource "azurerm_storage_container" "tfstate" {
  name                  = var.container_name
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private" # No public access
}

# --- Lock with Azure AD (prevents concurrent state writes) ---
resource "azurerm_management_lock" "tfstate" {
  name       = "tfstate-storage-lock"
  scope      = azurerm_storage_account.tfstate.id
  lock_level = "CanNotDelete"
  notes      = "Locked to prevent accidental deletion of Terraform state"
}