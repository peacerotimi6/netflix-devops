# Dev Environment Configuration

resource_group_name = "netflix-app-dev-rg"
location            = "eastus"
acr_name            = "netflixappdevacr"
aks_cluster_name    = "netflix-app-dev-aks"
dns_prefix          = "netflix-dev"
kubernetes_version  = "1.33"
key_vault_name      = "netflix-dev-kv"

# Networking
vnet_name          = "netflix-dev-vnet"
vnet_address_space = "10.0.0.0/16"

# System node pool — zone 1
system_node_count   = 1
system_node_vm_size = "Standard_D7s_v3"
system_min_count    = 1
system_max_count    = 3

# App node pool — zone 1
app_node_count   = 1
app_node_vm_size = "Standard_D7s_v3"
app_min_count    = 1
app_max_count    = 5
