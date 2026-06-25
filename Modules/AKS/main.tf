# ============================================================
# AKS Module — Multi-zone node pools, OIDC, Workload Identity
# ============================================================

# checkov:skip=CKV_AZURE_115: Private cluster requires VPN/private DNS infrastructure not in scope for this environment
# checkov:skip=CKV_AZURE_6:   API server authorized IP ranges not set; use Azure RBAC + private cluster in production
# checkov:skip=CKV_AZURE_170: Paid SLA SKU (~$100/mo) not justified for dev; enable Standard tier for production
# checkov:skip=CKV_AZURE_117: Disk encryption set (CMK) requires separate key management infrastructure
# checkov:skip=CKV_AZURE_226: Ephemeral OS disks conflict with explicit os_disk_size_gb; not used here
# checkov:skip=CKV_AZURE_141: Local admin disable requires full AAD RBAC setup; handled at deployment level
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version

  # OIDC + Workload Identity (replaces client secret auth)
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # Automatically upgrade patch versions
  automatic_upgrade_channel = "patch"

  # Azure Policy add-on for governance
  azure_policy_enabled = true

  # System node pool — availability zone 1
  default_node_pool {
    name                        = "system"
    temporary_name_for_rotation = "tmpnode"
    node_count                  = var.system_node_count
    vm_size                     = var.system_node_vm_size
    os_disk_size_gb             = var.os_disk_size_gb
    auto_scaling_enabled        = true
    min_count                   = var.system_min_count
    max_count                   = var.system_max_count
    max_pods                    = 50
    zones                       = ["1"]
    vnet_subnet_id              = var.system_subnet_id
    host_encryption_enabled     = false
    only_critical_addons_enabled = true
    node_labels = {
      "role" = "system"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
    service_cidr      = "10.100.0.0/16"
    dns_service_ip    = "10.100.0.10"
  }

  # Secrets Store CSI Driver with auto-rotation
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  oms_agent {
    log_analytics_workspace_id = var.create_log_analytics ? azurerm_log_analytics_workspace.aks[0].id : var.log_analytics_workspace_id
  }

  tags = var.tags
}

# App node pool — availability zone 1
resource "azurerm_kubernetes_cluster_node_pool" "app" {
  name                        = "apppool"
  temporary_name_for_rotation = "tmpapp"
  kubernetes_cluster_id       = azurerm_kubernetes_cluster.aks.id
  vm_size                     = var.app_node_vm_size
  node_count                  = var.app_node_count
  auto_scaling_enabled        = true
  min_count                   = var.app_min_count
  max_count                   = var.app_max_count
  max_pods                    = 50
  zones                       = ["1"]
  vnet_subnet_id              = var.app_subnet_id
  os_disk_size_gb             = var.os_disk_size_gb
  host_encryption_enabled     = false
  node_labels = {
    "role" = "app"
  }
  tags = var.tags
}

# Grant AKS pull access to ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  count                = var.attach_acr ? 1 : 0
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name = "AcrPull"
  scope                = var.acr_id
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "aks" {
  count               = var.create_log_analytics ? 1 : 0
  name                = "${var.cluster_name}-logs"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = var.tags
}
