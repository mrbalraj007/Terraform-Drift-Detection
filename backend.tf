terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstatemyproject002" # Must match bootstrap
    container_name       = "tfstate"
    key                  = "prod/terraform.tfstate" # Path inside the container
  }
}