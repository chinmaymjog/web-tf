### Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.p_short}-${var.e_short}-${var.l_short}"
  location = var.location
  lifecycle {
    ignore_changes = [tags]
  }
}

### Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.p_short}-${var.e_short}-${var.l_short}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.vnet_space
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_virtual_network_peering" "hub" {
  name                      = "hub-${var.env}"
  resource_group_name       = var.hub_rg_name
  virtual_network_name      = var.hub_vnet_name
  remote_virtual_network_id = azurerm_virtual_network.vnet.id
}

resource "azurerm_virtual_network_peering" "env" {
  name                      = "${var.env}-hub"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet.name
  remote_virtual_network_id = var.hub_vnet_id
}


resource "azurerm_subnet" "web" {
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
  name                 = "snet-web-${var.p_short}-${var.e_short}-${var.l_short}"
  address_prefixes     = var.snet_web
  service_endpoints    = ["Microsoft.Sql", "Microsoft.Storage", "Microsoft.KeyVault"]
}

resource "azurerm_subnet" "db" {
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
  name                 = "snet-db-${var.p_short}-${var.e_short}-${var.l_short}"
  address_prefixes     = var.snet_db

  service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]

  delegation {
    name = "mysql"
    service_delegation {
      name    = "Microsoft.DBforMySQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "netapp" {
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
  name                 = "snet-netapp-${var.p_short}-${var.e_short}-${var.l_short}"
  address_prefixes     = var.snet_netapp

  delegation {
    name = "netapp"
    service_delegation {
      name    = "Microsoft.Netapp/volumes"
      actions = ["Microsoft.Network/networkinterfaces/*", "Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }

}

### Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-${var.p_short}-${var.e_short}-${var.l_short}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_network_security_rule" "web" {
  name                         = "WebAccess"
  priority                     = 100
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_ranges      = ["80", "443"]
  source_address_prefix        = "*"
  destination_address_prefixes = var.snet_web
  resource_group_name          = azurerm_resource_group.rg.name
  network_security_group_name  = azurerm_network_security_group.nsg.name
}

resource "azurerm_subnet_network_security_group_association" "nsg-web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_subnet_network_security_group_association" "nsg-db" {
  subnet_id                 = azurerm_subnet.db.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_subnet_network_security_group_association" "nsg-netapp" {
  subnet_id                 = azurerm_subnet.netapp.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

### Load Balancer
resource "azurerm_public_ip" "pip" {
  name                = "pip-${var.p_short}-${var.e_short}-${var.l_short}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_lb" "lb" {
  name                = "lb-${var.p_short}-${var.e_short}-${var.l_short}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  lifecycle {
    ignore_changes = [tags]
  }
  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.pip.id
  }
}

resource "azurerm_lb_backend_address_pool" "pool" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "BackEndAddressPool"
}

resource "azurerm_lb_probe" "http-prob" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "http"
  protocol        = "Http"
  port            = 80
  request_path    = "/"
}

resource "azurerm_lb_probe" "https-prob" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "https"
  protocol        = "Https"
  port            = 443
  request_path    = "/"
}

resource "azurerm_lb_rule" "http" {
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "http"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.pool.id]
  probe_id                       = azurerm_lb_probe.http-prob.id
  disable_outbound_snat          = "true"
}

resource "azurerm_lb_rule" "https" {
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "https"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.pool.id]
  probe_id                       = azurerm_lb_probe.https-prob.id
  disable_outbound_snat          = "true"
}

resource "azurerm_lb_outbound_rule" "outbount" {
  name                    = "OutboundRule"
  loadbalancer_id         = azurerm_lb.lb.id
  protocol                = "All"
  backend_address_pool_id = azurerm_lb_backend_address_pool.pool.id

  frontend_ip_configuration {
    name = "PublicIPAddress"
  }
}

### Web Servers
resource "azurerm_network_interface" "nic" {
  count               = var.webvm_count
  name                = "nic-${var.p_short}-${var.e_short}-${var.l_short}-${count.index}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  lifecycle {
    ignore_changes = [tags]
  }
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "nic-pool" {
  count                   = var.webvm_count
  network_interface_id    = azurerm_network_interface.nic[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.pool.id
}

resource "azurerm_linux_virtual_machine" "web" {
  count               = var.webvm_count
  name                = "web-${var.p_short}-${var.e_short}-${var.l_short}-${count.index}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  size                = var.webvm_size
  admin_username      = var.vm_user
  network_interface_ids = [
    azurerm_network_interface.nic[count.index].id,
  ]
  lifecycle {
    ignore_changes = [tags]
  }
  admin_ssh_key {
    username   = var.vm_user
    public_key = file("../sshkey/azureuser_rsa.pub")
  }

  os_disk {
    name                 = "osdiskweb${var.p_short}${var.e_short}${var.l_short}${count.index}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = var.wbbvm_osdisk
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

resource "azurerm_managed_disk" "data" {
  count                = var.webvm_count
  name                 = "diskweb${var.p_short}${var.e_short}${var.l_short}${count.index}"
  location             = var.location
  resource_group_name  = azurerm_resource_group.rg.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.wbbvm_datadisk
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_virtual_machine_data_disk_attachment" "disk-asso" {
  count              = var.webvm_count
  managed_disk_id    = azurerm_managed_disk.data[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.web[count.index].id
  lun                = "10"
  caching            = "ReadWrite"
}

### Azure Front Door origin
resource "azurerm_cdn_frontdoor_origin" "origin" {
  name                          = "origin-${var.p_short}-${var.e_short}-${var.l_short}"
  cdn_frontdoor_origin_group_id = var.origin_group_id
  enabled                       = true

  certificate_name_check_enabled = false

  host_name  = azurerm_public_ip.pip.ip_address
  http_port  = 80
  https_port = 443
  priority   = 1
  weight     = 1000
}

resource "azurerm_cdn_frontdoor_route" "route" {
  name                          = "default-route"
  cdn_frontdoor_endpoint_id     = var.endpoint_id
  cdn_frontdoor_origin_group_id = var.origin_group_id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.origin.id]
  enabled                       = true

  forwarding_protocol    = "HttpOnly"
  https_redirect_enabled = true
  patterns_to_match      = ["/*"]
  supported_protocols    = ["Http", "Https"]
  link_to_default_domain = true
}

### Azure Netapp Volume
resource "azurerm_netapp_volume" "netapp_volume" {
  name                = "volume-${var.p_short}-${var.e_short}-${var.l_short}"
  location            = var.location
  zone                = "1"
  resource_group_name = var.hub_rg_name
  account_name        = var.netapp_account_name
  pool_name           = var.netapp_pool_name
  volume_path         = "${var.p_short}-${var.e_short}-${var.l_short}"
  service_level       = var.netapp_volume_sku
  subnet_id           = azurerm_subnet.netapp.id
  protocols           = ["NFSv4.1"]
  security_style      = "unix"
  storage_quota_in_gb = var.storage_quota_in_gb

  export_policy_rule {
    rule_index          = 1
    allowed_clients     = ["0.0.0.0"]
    protocols_enabled   = ["NFSv4.1"]
    unix_read_write     = "true"
    root_access_enabled = "true"
  }
  lifecycle {
    ignore_changes = [tags]
  }
}

### MySQL
locals {
  dbadminuser = "${var.env}mysqladmin"
}

resource "random_password" "dbadminpassword" {
  length  = 16
  special = "true"
}

resource "azurerm_private_dns_zone_virtual_network_link" "vnet-link" {
  name                  = azurerm_virtual_network.vnet.name
  private_dns_zone_name = var.dns_zone_name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  resource_group_name   = var.hub_rg_name
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_mysql_flexible_server" "mysql" {
  name                   = "mysql-${var.p_short}-${var.e_short}-${var.l_short}"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = var.location
  administrator_login    = local.dbadminuser
  administrator_password = random_password.dbadminpassword.result
  backup_retention_days  = 7
  delegated_subnet_id    = azurerm_subnet.db.id
  private_dns_zone_id    = var.dns_zone_id
  sku_name               = var.dbsku
  version                = "8.0.21"
  lifecycle {
    ignore_changes = [zone, tags]
  }
  storage {
    size_gb = var.dbsize
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.vnet-link]
}

### Key Vault DB secret
resource "azurerm_key_vault_secret" "dbadmin" {
  name         = "${var.e_short}-dbadmin"
  value        = local.dbadminuser
  key_vault_id = var.key_vault_id
}

resource "azurerm_key_vault_secret" "dbpass" {
  name         = "${var.e_short}-dbpass"
  value        = random_password.dbadminpassword.result
  key_vault_id = var.key_vault_id
}