project             = "star"
p_short             = "str"
env                 = "Production"
e_short             = "prd"
location            = "centralindia"
l_short             = "inc"
vnet_space          = ["10.0.1.0/24"]
snet_web            = ["10.0.1.0/26"]
snet_db             = ["10.0.1.64/26"]
snet_netapp         = ["10.0.1.128/26"]
webvm_size          = "Standard_B2s"
webvm_count         = "2"
wbbvm_osdisk        = 64
wbbvm_datadisk      = 64
vm_user             = "azureuser"
dbsku               = "GP_Standard_D2ads_v5"
dbsize              = 20
ip_allow            = ["152.58.17.126"]
netapp_volume_sku   = "Standard"
storage_quota_in_gb = 100

# hub_rg_name         = 
# hub_vnet_name       = 
# hub_vnet_id         = 
# endpoint_id         = 
# origin_group_id     = 
# netapp_account_name = 
# netapp_pool_name    = 
# dns_zone_name       = 
# dns_zone_id         = 
# key_vault_id        = 