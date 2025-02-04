variable "project" {
  description = "Project name"
}

variable "p_short" {
  description = "Project short name"
}

variable "env" {
  description = "Define environmnet to deply"
}

variable "e_short" {
  description = "Environmnet short name"
}

variable "location" {
  description = "Azure region to deploy"
}

variable "l_short" {
  description = "Location short name"
}

variable "vnet_space" {
  description = "Address space for vnet"
}

variable "snet_web" {
  description = "Address space for web subnet"
}

variable "vm_user" {
  description = "Username for vm user"
}

variable "bastion_size" {
  description = "Size for VM"
}

variable "bastion_osdisk" {
  description = "Os disk size for VM in GB"
}

variable "bastion_datadisk" {
  description = "Data disk size for VM in GB"
}

variable "ip_allow" {
  description = "List of IPs to whitelist"
}

variable "netapp_sku" {
  description = "Netapp SKU"
}

variable "netapp_pool_size" {
  description = "Netapp pool size in TB"
}