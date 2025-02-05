terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.17"
    }
  }
}

provider "azurerm" {
  features {}
}
