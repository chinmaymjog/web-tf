terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.17.0"
    }
  }

  backend "local" {
    path = "hub.tfstate"
  }
}

provider "azurerm" {
  features {}
}
