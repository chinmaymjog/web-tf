### Part 2: Automating Azure Infrastructure with Terraform: A Deep Dive

![Architecture](../images/terraform.png)

Terraform, a widely-used Infrastructure as Code (IaC) tool, helps manage and automate cloud infrastructure. In this blog post, we'll explore a Terraform script to deploy various Azure resources. The script demonstrates how to provision a resource group, CDN, virtual network, security groups, load balancers, and more.

Full code is available at github

### Key Components of the Terraform Script

#### 1. **Defining the Azure Provider**
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

#### 2. **Resource Group Creation**
```
resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.p_short}-${var.e_short}-${var.l_short}"
  location = var.location
}
```
This block creates a **Resource Group**—a container for managing Azure resources. By using variables like `var.p_short` (project), `var.e_short` (environment), and `var.l_short` (location), you maintain flexibility and dynamic naming for different environments.

#### 3. **CDN Profile**
```
resource "azurerm_cdn_frontdoor_profile" "fd" {
  name                = "fd-${var.p_short}-${var.e_short}-${var.l_short}"
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Standard_AzureFrontDoor"
}
``` 
This block provisions an **Azure CDN Frontdoor Profile** to enhance content delivery and optimize performance for web applications.

#### 4. **Virtual Network and Subnets**
```
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.p_short}-${var.e_short}-${var.l_short}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.vnet_space
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

This defines a **Virtual Network (VNet)** and two subnets: a web subnet for frontend resources and a database subnet, delegated for MySQL server hosting. Service endpoints enhance security by enabling private communication with Azure services.

#### 5. **Network Security Group**
```
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-${var.p_short}-${var.e_short}-${var.l_short}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "web" {
  name                        = "WebAccess"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80,443"
  source_address_prefix       = "*"
  destination_address_prefixs = var.snet_web
  network_security_group_name = azurerm_network_security_group.nsg.name
} 
```
A **Network Security Group (NSG)** is created with security rules that allow inbound access to ports 80 (HTTP) and 443 (HTTPS). These rules protect resources by restricting or allowing traffic based on specific conditions.

#### 6. **Linux Virtual Machine**
```
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "vm-${var.p_short}-${var.e_short}-${var.l_short}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  size                = var.webvm_size
  admin_username      = var.vm_user
  network_interface_ids = [
    azurerm_network_interface.nic-vm.id,
  ]

  admin_ssh_key {
    username   = var.vm_user
    public_key = file("./sshkey/azureuser_rsa.pub")
  }

  os_disk {
    name                 = "osdiskvm${var.p_short}${var.e_short}${var.l_short}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
```

This block deploys an **Ubuntu Linux virtual machine**. Key details include the VM size, admin username, SSH key for secure access, and disk configuration.

#### 7. **Load Balancer and Public IP**
```
resource "azurerm_lb" "lb" {
  name                = "lbi-${var.p_short}-${var.e_short}-${var.l_short}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.pip.id
  }
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
}
```

This block configures an **Azure Load Balancer** and sets up a rule to distribute HTTPS traffic across backend VMs.

### Conclusion

This Terraform script demonstrates a powerful way to automate the creation of Azure resources, from virtual networks to virtual machines, security groups, and load balancers. By managing infrastructure as code, you can maintain consistency across deployments, scale effortlessly, and simplify changes to your environment.