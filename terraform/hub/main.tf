### Resource Group
resource "azurerm_resource_group" "hub" {
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
  resource_group_name = azurerm_resource_group.hub.name
  address_space       = var.vnet_space
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_subnet" "web" {
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.hub.name
  name                 = "snet-web-${var.p_short}-${var.e_short}-${var.l_short}"
  address_prefixes     = var.snet_web
  service_endpoints    = ["Microsoft.Sql", "Microsoft.Storage", "Microsoft.KeyVault"]
}

### Network Security Group
resource "azurerm_network_security_group" "hub-nsg" {
  name                = "nsg-${var.p_short}-${var.e_short}-${var.l_short}"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub.name
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
  resource_group_name          = azurerm_resource_group.hub.name
  network_security_group_name  = azurerm_network_security_group.hub-nsg.name
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
  resource_group_name          = azurerm_resource_group.hub.name
  network_security_group_name  = azurerm_network_security_group.hub-nsg.name
}

resource "azurerm_network_security_rule" "jenkis" {
  name                         = "Jenkins"
  priority                     = 102
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = 8080
  source_address_prefixes      = var.ip_allow
  destination_address_prefixes = azurerm_network_interface.nic-vm.private_ip_addresses
  resource_group_name          = azurerm_resource_group.hub.name
  network_security_group_name  = azurerm_network_security_group.hub-nsg.name
}

resource "azurerm_subnet_network_security_group_association" "nsg-web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.hub-nsg.id
}

### Bastion host
resource "azurerm_public_ip" "pip-vm" {
  name                = "pip-vm-${var.p_short}-${var.e_short}-${var.l_short}"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_network_interface" "nic-vm" {
  name                = "nic-vm-${var.p_short}-${var.e_short}-${var.l_short}"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub.name
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
  resource_group_name = azurerm_resource_group.hub.name
  location            = var.location
  size                = var.bastion_size
  admin_username      = var.vm_user
  network_interface_ids = [
    azurerm_network_interface.nic-vm.id,
  ]
  lifecycle {
    ignore_changes = [tags]
  }
  admin_ssh_key {
    username   = var.vm_user
    public_key = file("../sshkey/azureuser_rsa.pub")
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
    source      = "../sshkey/azureuser_rsa"
    destination = "/home/${var.vm_user}/.ssh/id_rsa"

    connection {
      type        = "ssh"
      host        = azurerm_linux_virtual_machine.vm.public_ip_address
      private_key = file("../sshkey/azureuser_rsa")
      user        = var.vm_user
    }
  }
}

resource "azurerm_managed_disk" "data-vm" {
  name                 = "diskvm${var.p_short}${var.e_short}${var.l_short}"
  location             = var.location
  resource_group_name  = azurerm_resource_group.hub.name
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

### Azure Front Door
resource "azurerm_cdn_frontdoor_profile" "fd" {
  name                = "fd-${var.p_short}-${var.e_short}-${var.l_short}"
  resource_group_name = azurerm_resource_group.hub.name
  sku_name            = "Standard_AzureFrontDoor"
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_cdn_frontdoor_endpoint" "prod-endpoint" {
  name                     = "prod-endpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd.id
}

resource "azurerm_cdn_frontdoor_endpoint" "preprod-endpoint" {
  name                     = "preprod-endpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd.id
}


resource "azurerm_cdn_frontdoor_origin_group" "prod_origin_group" {
  name                     = "prod-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd.id
  session_affinity_enabled = false

  restore_traffic_time_to_healed_or_new_endpoint_in_minutes = 10

  health_probe {
    interval_in_seconds = 100
    path                = "/"
    protocol            = "Http"
    request_type        = "HEAD"
  }

  load_balancing {
    additional_latency_in_milliseconds = 50
    sample_size                        = 4
    successful_samples_required        = 3
  }
}

resource "azurerm_cdn_frontdoor_origin_group" "preprod_origin_group" {
  name                     = "preprod-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd.id
  session_affinity_enabled = false

  restore_traffic_time_to_healed_or_new_endpoint_in_minutes = 10

  health_probe {
    interval_in_seconds = 100
    path                = "/"
    protocol            = "Http"
    request_type        = "HEAD"
  }

  load_balancing {
    additional_latency_in_milliseconds = 50
    sample_size                        = 4
    successful_samples_required        = 3
  }
}

### Azure Netapp Files
resource "azurerm_netapp_account" "netapp_account" {
  name                = "netapp-${var.p_short}-${var.e_short}-${var.l_short}"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub.name
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_netapp_pool" "netapp_pool" {
  name                = "pool-${var.p_short}-${var.e_short}-${var.l_short}"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub.name
  account_name        = azurerm_netapp_account.netapp_account.name
  service_level       = var.netapp_sku
  size_in_tb          = var.netapp_pool_size
  lifecycle {
    ignore_changes = [tags]
  }
}

### Private DNS & MySQL
resource "azurerm_private_dns_zone" "dns-zone" {
  name                = "${var.p_short}.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.hub.name
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "vnet-link" {
  name                  = azurerm_virtual_network.vnet.name
  private_dns_zone_name = azurerm_private_dns_zone.dns-zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  resource_group_name   = azurerm_resource_group.hub.name
  lifecycle {
    ignore_changes = [tags]
  }
}

### Key Vault
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                        = "kv-${var.p_short}-${var.e_short}-${var.l_short}"
  location                    = var.location
  resource_group_name         = azurerm_resource_group.hub.name
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
    virtual_network_subnet_ids = [azurerm_subnet.web.id]
    ip_rules                   = var.ip_allow
  }
}

resource "azurerm_key_vault_secret" "key" {
  name         = "sshkey"
  value        = replace(file("../sshkey/azureuser_rsa"), "/\n/", "\n")
  key_vault_id = azurerm_key_vault.kv.id
}