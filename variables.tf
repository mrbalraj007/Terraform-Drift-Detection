variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-nsg-demo"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US"
}

variable "nsg_name" {
  description = "Name of the Network Security Group"
  type        = string
  default     = "nsg-demo"
}

variable "allowed_ssh_source_ip" {
  description = "Source IP allowed for SSH access. Replace with your actual IP."
  type        = string
  default     = "0.0.0.0/0"   # ⚠️ Restrict this to your IP in production
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "demo"
    ManagedBy   = "Terraform"
    Project     = "Terraform-Drift-Detection"
  }
}