terraform {
  required_version = ">= 1.1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.60.0"
    }
  }

}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.customer}-${terraform.workspace}-${var.location}"
  location = var.location

  tags = {
    "environment"  = "client demo"
    "productowner" = "JohnFox"
    "deployedBy"   = "terraformCloud"
  }
}




resource "azurerm_private_dns_zone" "snapvideo" {
  name                = "snapvideo.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "snapvideo" {
  name                  = "snapvideoVnetZone.com"
  private_dns_zone_name = azurerm_private_dns_zone.snapvideo.name
  virtual_network_id    = azurerm_virtual_network.snapvideo.id
  resource_group_name   = azurerm_resource_group.rg.name

  depends_on = [azurerm_private_dns_zone_virtual_network_link.snapvideo, azurerm_subnet.database]

}