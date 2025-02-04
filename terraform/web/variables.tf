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

variable "snet_db" {
  description = "Address space for db subnet"
}

variable "snet_netapp" {
  description = "Address space for netapp subnet"
}

variable "vm_user" {
  description = "Username for vm user"
}

variable "webvm_size" {
  description = "Size for VM"
}

variable "webvm_count" {
  description = "Count of Web VMs"
}

variable "wbbvm_osdisk" {
  description = "OS disk size for Web VM in GB"
}

variable "wbbvm_datadisk" {
  description = "Data disk size for Web VM in GB"
}

variable "dbsku" {
  description = "SKU for Azure Database for MySQL"
}

variable "dbsize" {
  description = "Database size in GB"
}

variable "ip_allow" {
  description = "List of IPs to whitelist"
}

variable "netapp_volume_sku" {
  description = "SKU for netapp volume"
}

variable "storage_quota_in_gb" {
  description = "Netapp volume size in GB"
}

variable "hub_rg_name" {
  description = "HUB resource group name"
}

variable "hub_vnet_name" {
  description = "Hub VNET name"
}

variable "hub_vnet_id" {
  description = "Hub VNET id"
}

variable "endpoint_id" {
  description = "Azure front door endpoint id"
}

variable "origin_group_id" {
  description = "Azure front door origin group id"
}

variable "netapp_account_name" {
  description = "NetApp account name"
}

variable "netapp_pool_name" {
  description = "NetApp pool name"
}

variable "dns_zone_name" {
  description = "Private DNS zone name"
}

variable "dns_zone_id" {
  description = "Private DNS zone id"
}

variable "key_vault_id" {
  description = "Key Vault id"
}