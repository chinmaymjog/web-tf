output "details" {
  value = <<CUSTOM_OUTPUT
######################################################
Resource Group Name = ${azurerm_resource_group.rg.name}
MySQL server Name = ${azurerm_mysql_flexible_server.mysql.name}
Load Balancer IP = ${azurerm_public_ip.pip.ip_address}
######################################################
CUSTOM_OUTPUT  
}
