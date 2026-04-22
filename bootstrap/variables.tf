variable "resource_group_name" {
  description = "Name of the resource group for Terraform state"
  type        = string
  default     = "rg-terraform-state"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US"
}

variable "storage_account_name" {
  description = "Globally unique storage account name (lowercase, 3-24 chars)"
  type        = string
  default     = "tfstatemyproject002" # ⚠️ Change this to something unique
}

variable "container_name" {
  description = "Blob container name for state files"
  type        = string
  default     = "tfstate"
}