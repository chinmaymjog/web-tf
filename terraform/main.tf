terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.116.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.p_short}-${var.e_short}-${var.l_short}"
  location = var.location
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_cdn_frontdoor_profile" "fd" {
  name                = "fd-${var.p_short}-${var.e_short}-${var.l_short}"
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Standard_AzureFrontDoor"
  lifecycle {
    ignore_changes = [tags]
  }
}

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

resource "azurerm_network_security_rule" "ssh" {
  name                         = "SSH"
  priority                     = 101
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = 22
  source_address_prefixes      = var.ip_allow
  destination_address_prefixes = azurerm_network_interface.nic-vm.private_ip_addresses
  resource_group_name          = azurerm_resource_group.rg.name
  network_security_group_name  = azurerm_network_security_group.nsg.name
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.p_short}-${var.e_short}-${var.l_short}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.vnet_space
  lifecycle {
    ignore_changes = [tags]
  }
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

resource "azurerm_subnet_network_security_group_association" "nsg-web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_subnet_network_security_group_association" "nsg-db" {
  subnet_id                 = azurerm_subnet.db.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_public_ip" "pip-vm" {
  name                = "pip-vm-${var.p_short}-${var.e_short}-${var.l_short}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_network_interface" "nic-vm" {
  name                = "nic-vm-${var.p_short}-${var.e_short}-${var.l_short}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  lifecycle {
    ignore_changes = [tags]
  }
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip-vm.id
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "vm-${var.p_short}-${var.e_short}-${var.l_short}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  size                = var.webvm_size
  admin_username      = var.vm_user
  network_interface_ids = [
    azurerm_network_interface.nic-vm.id,
  ]
  lifecycle {
    ignore_changes = [tags]
  }
  admin_ssh_key {
    username   = var.vm_user
    public_key = file("./sshkey/azureuser_rsa.pub")
  }

  os_disk {
    name                 = "osdiskvm${var.p_short}${var.e_short}${var.l_short}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = var.bastion_osdisk
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}


resource "null_resource" "key_upload" {
    provisioner "file" {
    source = "./sshkey/azureuser_rsa"
    destination = "/home/${var.vm_user}/.ssh/id_rsa"

    connection {
      type = "ssh"
      host = azurerm_linux_virtual_machine.vm.public_ip_address
      private_key = file("./sshkey/azureuser_rsa")
      user = var.vm_user
    }
  }
}
resource "azurerm_managed_disk" "data-vm" {
  name                 = "diskvm${var.p_short}${var.e_short}${var.l_short}"
  location             = var.location
  resource_group_name  = azurerm_resource_group.rg.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.bastion_datadisk
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_virtual_machine_data_disk_attachment" "disk-asso-vm" {
  managed_disk_id    = azurerm_managed_disk.data-vm.id
  virtual_machine_id = azurerm_linux_virtual_machine.vm.id
  lun                = "10"
  caching            = "ReadWrite"
}

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
  name                = "lbi-${var.p_short}-${var.e_short}-${var.l_short}"
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
    public_key = file("./sshkey/azureuser_rsa.pub")
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

resource "random_integer" "stid" {
  min = 0
  max = 1000
}

resource "azurerm_storage_account" "staccount" {
  name                     = "st${var.p_short}${var.e_short}${var.l_short}${random_integer.stid.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.location
  account_tier             = "Premium"
  account_replication_type = "LRS"
  account_kind             = "FileStorage"
  lifecycle {
    ignore_changes = [tags]
  }
  network_rules {
    default_action             = "Deny"
    virtual_network_subnet_ids = [azurerm_subnet.web.id, azurerm_subnet.db.id]
    ip_rules                   = var.ip_allow
  }
}

resource "azurerm_private_dns_zone" "dns-zome" {
  name                = "${var.p_short}.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "vnet-link" {
  name                  = azurerm_virtual_network.vnet.name
  private_dns_zone_name = azurerm_private_dns_zone.dns-zome.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  resource_group_name   = azurerm_resource_group.rg.name
  lifecycle {
    ignore_changes = [ tags]
  }
}

resource "azurerm_mysql_flexible_server" "mysql" {
  name                   = "mysql-${var.p_short}-${var.e_short}-${var.l_short}"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = var.location
  administrator_login    = var.dbadmin
  administrator_password = var.dbpass
  backup_retention_days  = 7
  delegated_subnet_id    = azurerm_subnet.db.id
  private_dns_zone_id    = azurerm_private_dns_zone.dns-zome.id
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

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                        = "kv-${var.p_short}-${var.e_short}-${var.l_short}"
  location                    = var.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  lifecycle {
    ignore_changes = [tags]
  }
  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    certificate_permissions = [
      "Get", "List", "Update", "Create", "Import", "Delete", "Recover", "Backup", "Restore", "ManageContacts", "ManageIssuers", "GetIssuers", "ListIssuers", "SetIssuers", "DeleteIssuers",
    ]

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore",
    ]

    key_permissions = [
      "Get", "List", "Update", "Create", "Import", "Delete", "Recover", "Backup", "Restore", "GetRotationPolicy", "SetRotationPolicy", "Rotate",
    ]
  }

  network_acls {
    bypass                     = "AzureServices"
    default_action             = "Deny"
    virtual_network_subnet_ids = [azurerm_subnet.web.id, azurerm_subnet.db.id]
    ip_rules                   = var.ip_allow
  }
}

resource "azurerm_key_vault_secret" "key" {
  name         = "sshkey"
  value        = replace(file("./sshkey/azureuser_rsa"), "/\n/", "\n")
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "dbadmin" {
  name         = "dbadmin"
  value        = var.dbadmin
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "dbpass" {
  name         = "dbpass"
  value        = var.dbpass
  key_vault_id = azurerm_key_vault.kv.id
}