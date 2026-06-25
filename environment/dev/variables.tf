variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus"
}

variable "acr_name" {
  description = "Name of the Azure Container Raegistry"
  type        = string
}

variable "aks_cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.33"
}

variable "key_vault_name" {
  description = "Name of the Azure Key Vault"
  type        = string
}

# -------------------------------------------------------
# Networking
# -------------------------------------------------------
variable "vnet_name" {
  description = "Name of the Virtual Network"
  type        = string
  default     = "netflix-dev-vnet"
}

variable "vnet_address_space" {
  description = "Address space for the VNet"
  type        = string
  default     = "10.0.0.0/16"
}

# -------------------------------------------------------
# System node pool (availability zone 1)
# -------------------------------------------------------
variable "system_node_count" {
  description = "Initial node count for the system node pool"
  type        = number
  default     = 1
}

variable "system_node_vm_size" {
  description = "VM size for the system node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "system_min_count" {
  description = "Minimum node count for system pool autoscaling"
  type        = number
  default     = 1
}

variable "system_max_count" {
  description = "Maximum node count for system pool autoscaling"
  type        = number
  default     = 3
}

# -------------------------------------------------------
# App node pool (availability zone 2)
# -------------------------------------------------------
variable "app_node_count" {
  description = "Initial node count for the app node pool"
  type        = number
  default     = 1
}

variable "app_node_vm_size" {
  description = "VM size for the app node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "app_min_count" {
  description = "Minimum node count for app pool autoscaling"
  type        = number
  default     = 1
}

variable "app_max_count" {
  description = "Maximum node count for app pool autoscaling"
  type        = number
  default     = 5
}
