provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-bgarcia-dvfinlab"
  location = "westeurope"

  tags = {
    owner      = var.owner
    environment = var.entorno
  }
}

resource "azurerm_virtual_network" "vnet" {
  name                = var.nombre_vnet
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]

  tags = var.vnet_tags
}

output "vnet_name" {
  value = azurerm_virtual_network.vnet.name
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}
