output "start" {
  value = <<CUSTOM_OUTPUT
######################################################
Resource Group Name = ${azurerm_resource_group.rg.name}
Front Door Name = ${azurerm_cdn_frontdoor_profile.fd.name}
Key Vault Name = ${azurerm_key_vault.kv.name}
MySQL server Name = ${azurerm_mysql_flexible_server.mysql.name}
Storage Account Name = ${azurerm_storage_account.staccount.name}
Load Balancer IP = ${azurerm_public_ip.pip.ip_address}
VM IP = ${azurerm_public_ip.pip-vm.ip_address}
######################################################
CUSTOM_OUTPUT  
}
