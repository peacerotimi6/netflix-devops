# Production Environment Configuration

resource_group_name = "netflix-app-prod-rg"
location            = "eastus"
acr_name            = "netflixappprodacr"
aks_cluster_name    = "netflix-app-prod-aks"
dns_prefix          = "netflix-prod"
kubernetes_version  = "1.33"
key_vault_name      = "netflix-prod-kv"

# Networking
vnet_name          = "netflix-prod-vnet"
vnet_address_space = "10.1.0.0/16"

# System node pool — zone 1
system_node_count   = 1
system_node_vm_size = "Standard_D2ads_v7"
system_min_count    = 1
system_max_count    = 3

# App node pool — zone 2
app_node_count   = 2
app_node_vm_size = "Standard_D2s_v3"
app_min_count    = 2
app_max_count    = 6
