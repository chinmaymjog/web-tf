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

variable "webvm_size" {
  description = "Size for VM"
}

variable "webvm_count" {
  description = "Count of Web VMs"
}

variable "vm_user" {
  description = "Username for vm user"
}

variable "bastion_osdisk" {
  description = "Os disk size for VM in GB"
}

variable "bastion_datadisk" {
  description = "Data disk size for VM in GB"
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

variable "dbadmin" {
  description = "User name for DB admin"
}

variable "dbpass" {
  description = "Password for DB admin"
}

variable "ip_allow" {
  description = "List of IPs to whitelist"
}
