# ============================================================
#  main.tf — Dev Environment
# ============================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstatenetflixdev"
    container_name       = "tfstate"
    key                  = "dev-v2.terraform.tfstate"
    # Use managed identity for state access instead of storage keys
    use_azuread_auth = true
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# -------------------------------------------------------
# Resource Group
# -------------------------------------------------------
module "resource_group" {
  source              = "../../Modules/resource-group"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = local.common_tags
}

# -------------------------------------------------------
# Networking — VNet + subnets + NSGs
# -------------------------------------------------------
module "networking" {
  source = "../../Modules/networking"

  vnet_name           = var.vnet_name
  location            = module.resource_group.location
  resource_group_name = module.resource_group.resource_group_name
  vnet_address_space  = var.vnet_address_space

  tags = local.common_tags

  depends_on = [module.resource_group]
}

# -------------------------------------------------------
# Azure Container Registry
# -------------------------------------------------------
module "acr" {
  source = "../../Modules/ACR"

  acr_name            = var.acr_name
  resource_group_name = module.resource_group.resource_group_name
  location            = module.resource_group.location
  sku                 = "Basic"

  # Use AKS managed identity with AcrPull role (no admin credentials)
  admin_enabled = false

  tags = local.common_tags
}

# -------------------------------------------------------
# Azure Kubernetes Service — Multi-zone node pools
# -------------------------------------------------------
module "aks" {
  source = "../../Modules/AKS"

  cluster_name        = var.aks_cluster_name
  location            = module.resource_group.location
  resource_group_name = module.resource_group.resource_group_name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version
  os_disk_size_gb     = 30

  # System node pool — zone 1
  system_node_count   = var.system_node_count
  system_node_vm_size = var.system_node_vm_size
  system_min_count    = var.system_min_count
  system_max_count    = var.system_max_count
  system_subnet_id    = module.networking.aks_system_subnet_id

  # App node pool — zone 2
  app_node_count   = var.app_node_count
  app_node_vm_size = var.app_node_vm_size
  app_min_count    = var.app_min_count
  app_max_count    = var.app_max_count
  app_subnet_id    = module.networking.aks_app_subnet_id

  # AcrPull role assignment via managed identity
  attach_acr = true
  acr_id     = module.acr.acr_id

  create_log_analytics = true
  log_retention_days   = 30

  tags = local.common_tags

  depends_on = [module.resource_group, module.networking]
}

# -------------------------------------------------------
# Azure Key Vault
# -------------------------------------------------------
module "keyvault" {
  source = "../../Modules/keyvaults"

  key_vault_name      = var.key_vault_name
  location            = module.resource_group.location
  resource_group_name = module.resource_group.resource_group_name
  sku_name            = "standard"

  purge_protection_enabled   = true
  soft_delete_retention_days = 90

  # Use RBAC with least-privilege (Secret User = read-only)
  enable_rbac_authorization = true

  role_assignments = [
    {
      principal_id = module.aks.kubelet_identity_object_id
      role         = "Key Vault Secrets User"
    }
  ]

  tags = local.common_tags

  depends_on = [module.aks]
}

# -------------------------------------------------------
# Locals
# -------------------------------------------------------
locals {
  common_tags = {
    Environment = "dev"
    Project     = "netflix-streaming-app"
    ManagedBy   = "terraform"
  }
}
