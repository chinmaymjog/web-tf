project             = "star"
p_short             = "str"
env                 = "Preproduction"
e_short             = "pprd"
location            = "centralindia"
l_short             = "inc"
vnet_space          = ["10.0.2.0/24"]
snet_web            = ["10.0.2.0/26"]
snet_db             = ["10.0.2.64/26"]
snet_netapp         = ["10.0.2.128/26"]
webvm_size          = "Standard_B2s"
webvm_count         = "2"
wbbvm_osdisk        = 64
wbbvm_datadisk      = 64
vm_user             = "azureuser"
dbsku               = "GP_Standard_D2ads_v5"
dbsize              = 20
ip_allow            = ["152.58.16.59"]
netapp_volume_sku   = "Standard"
storage_quota_in_gb = 100

hub_vnet_name       = "vnet-str-hub-inc"
hub_rg_name         = "rg-str-hub-inc"
hub_vnet_id         = "/subscriptions/<Subscription ID>/resourceGroups/rg-str-hub-inc/providers/Microsoft.Network/virtualNetworks/vnet-str-hub-inc"
endpoint_id         = "/subscriptions/<Subscription ID>/resourceGroups/rg-str-hub-inc/providers/Microsoft.Cdn/profiles/fd-str-hub-inc/afdEndpoints/preprod-endpoint"
origin_group_id     = "/subscriptions/<Subscription ID>/resourceGroups/rg-str-hub-inc/providers/Microsoft.Cdn/profiles/fd-str-hub-inc/originGroups/preprod-origin-group"
netapp_account_name = "netapp-str-hub-inc"
netapp_pool_name    = "pool-str-hub-inc"
dns_zone_name       = "str.mysql.database.azure.com"
dns_zone_id         = "/subscriptions/<Subscription ID>/resourceGroups/rg-str-hub-inc/providers/Microsoft.Network/privateDnsZones/str.mysql.database.azure.com"
key_vault_id        = "/subscriptions/<Subscription ID>/resourceGroups/rg-str-hub-inc/providers/Microsoft.KeyVault/vaults/kv-str-hub-inc"