# Part 2: Terraform – Deploying Azure Infrastructure

![Architecture](./images/terraform.png)

I will demonstrates the use of Terraform to deploy Azure Infrastructure for shared web hosting.

1. [Introduction](#introduction)
2. [Resource Naming Convention](#resource-naming-convention)
3. [Terraform Script Overview](#terraform-script-overview)
4. [Resources Deployed](#resources-deployed)
    - [Resource Group](#resource-group)
    - [Virtual Network](#virtual-network)
    - [Network Security Group](#network-security-group)
    - [Bastion Host](#bastion-host)
    - [Load Balancer](#load-balancer)
    - [Web Servers](#web-servers)
    - [Azure NetApp Files](#azure-netapp-files)
    - [Azure Front Door](#azure-front-door)
    - [Private DNS & MySQL](#private-dns-mysql)
    - [Key Vault](#key-vault)
5. [How to Use](#how-to-use)
6. [Customization](#customization)

## Introduction

This repository contains a Terraform configuration that automates the provisioning of infrastructure on Microsoft Azure. It includes the setup of networking components, security, and virtual machines, along with integration with Azure Front Door and Azure NetApp Files.

Script uses various variables like `var.p_short` (project), `var.e_short` (environment), and `var.l_short` (location). Variable are passed in file [inputs.tfvars](../terraform/inputs.tfvars). More on it in [how to](#how-to-use) section.

## Resource Naming Convention

I follow the Azure best practices for naming resources. The naming convention used is as follows:

│ Resource Type  │ │ Project Abbr │ │ Environmnet Abbr │ │  Region Abbr │

e.g. fd-str-prd-inc
- `fd`: Abbreviation for Azure Front Door
- `str`: Abbreviation for the project name (e.g., Start)
- `prd`: Abbreviation for the environment (e.g., Production)
- `inc`: Abbreviation for the region (e.g., Central India)

Refer to the  
[Azure documnaming conventionentation](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming)  
[Azure Abbreviation recommendations](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations)  
[Azure region abbrevation](https://github.com/Azure/terraform-azurerm-caf-enterprise-scale/blob/main/modules/connectivity/locals.geo_codes.tf.json)

## Terraform Script Overview
[Script](../terraform/main.tf) starts with defining the Azure Provider. I have not defined terraform backend for state file. I am running it from my laptop so my state file is saved locally.

If you wish to define diffrent backend please [see](https://developer.hashicorp.com/terraform/language/backend/azurerm)
I am using Azure Service Principal and a Client Secret for Autehntication which is covered in [this guide](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_client_secret#creating-a-service-principal)
I am passing credntial to terraform as environmnet variable, [see](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_client_secret#configuring-the-service-principal-in-terraform)


```
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
```

This block declares the **`azurerm`** provider, which tells Terraform to use Azure as the cloud platform. It also specifies the version of the provider to ensure compatibility with the script. The **`features {}`** block is required but can remain empty for now.

## Resource Deployed
Here's a quick overview of the resources deployed by the script:

### Resource Group
The resource group is the container for all Azure resources.
This block creates a **`Resource Group`**—a container for managing Azure resources. 

```
resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.p_short}-${var.e_short}-${var.l_short}"
  location = var.location
}
```

### Virtual Network

This defines a **`Virtual Network (VNet)`** and two subnets: a web subnet for frontend resources and a database subnet, delegated for MySQL server hosting. Service endpoints enhance security by enabling private communication with Azure services.

```
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
```

### Network Security Group

This Terraform block defines an **`Azure Network Security Group (NSG)`** and associates it with web and database subnets. The NSG includes security rules for web traffic (HTTP/HTTPS) and SSH access. `WebAccess` rule Accepts traffic from any source (public internet). SSH rule Restricts `SSH` access to specific IP(s). Then the web and database subnets are associated with NSG which ensures security rules apply to all VMs in these subnets.

```
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

resource "azurerm_subnet_network_security_group_association" "nsg-web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_subnet_network_security_group_association" "nsg-db" {
  subnet_id                 = azurerm_subnet.db.id
  network_security_group_id = azurerm_network_security_group.nsg.id
} 
```

### Bastion host

This Terraform block sets up a bastion host VM, built using Ubuntu 24.04 LTS. A local SSH private key (azureuser_rsa) is securely copied to the VM, which will later be used by Ansible to connect to web servers.

```
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
```

### Load Balancer

This Terraform block sets up an **`Azure Load Balancer`** (Standard SKU) and creates a static public IP to ensure the Load Balancer has a fixed IP address. The public IP (PIP) is associated with the frontend IP configuration. A backend pool is defined where VMs will be added. Health probes monitor the availability of backend VMs. The Load Balancer forwards incoming HTTP (80) and HTTPS (443) traffic to the backend VMs.

```
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
```

### Web Servers

This Terraform block dynamically creates multiple Linux (Ubuntu 24.04 LTS) VMs and connects them to an Azure Load Balancer. It creates a separate NIC for each VM, with each NIC being attached to the `web` subnet. Additionally, each NIC is automatically added to the Azure Load Balancer's backend pool.

```
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
```


### Azure Netapp Files

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

### Azure Front Door

resource "azurerm_cdn_frontdoor_profile" "fd" {
  name                = "fd-${var.p_short}-${var.e_short}-${var.l_short}"
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Standard_AzureFrontDoor"
  lifecycle {
    ignore_changes = [tags]
  }
}

### Private DNS & MySQL

This Terraform block sets up a **`private DNS zone`** and a **`MySQL flexible server`**, linking the DNS zone to the virtual network (VNet) for private name resolution. The MySQL server is deployed in a private subnet, ensuring it has no public exposure. It also links the private DNS zone to the VNet, allowing VMs and other resources within the network to resolve MySQL addresses privately.

```
resource "azurerm_private_dns_zone" "dns-zone" {
  name                = "${var.p_short}.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "vnet-link" {
  name                  = azurerm_virtual_network.vnet.name
  private_dns_zone_name = azurerm_private_dns_zone.dns-zone.name
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
  private_dns_zone_id    = azurerm_private_dns_zone.dns-zone.id
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
```

### Key Vault

This Terraform block provisions an **`Azure Key Vault`** to securely store secrets, keys, and certificates. I am granting access to the currently logged-in identity with specific permissions to the vault. Secrets, SSH keys, and database credentials are being stored within the Key Vault.


```
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
```

## How to Use