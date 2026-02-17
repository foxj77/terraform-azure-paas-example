
resource "azurerm_virtual_network" "snapvideo" {
  name                = "vnet-${var.customer}-${terraform.workspace}-${var.location}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
  dns_servers         = ["10.0.0.4", "10.0.0.5"]

  tags = {
    "environment"  = "client demo"
    "productowner" = "JohnFox"
    "deployedBy"   = "terraformCloud"
  }
}

resource "azurerm_subnet" "aag" {
  name                 = "subnet-aag-${var.customer}-${terraform.workspace}-${var.location}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.snapvideo.name
  address_prefixes     = ["10.0.0.0/24"]
  depends_on           = [azurerm_virtual_network.snapvideo]
}

resource "azurerm_subnet" "web" {
  name                 = "subnet-web-${var.customer}-${terraform.workspace}-${var.location}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.snapvideo.name
  address_prefixes     = ["10.0.1.0/24"]
  depends_on           = [azurerm_virtual_network.snapvideo]

}

resource "azurerm_subnet" "backend" {
  name                 = "subnet-backend-${var.customer}-${terraform.workspace}-${var.location}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.snapvideo.name
  address_prefixes     = ["10.0.2.0/24"]
  depends_on           = [azurerm_virtual_network.snapvideo]
}

resource "azurerm_subnet" "database" {
  name                 = "subnet-database-${var.customer}-${terraform.workspace}-${var.location}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.snapvideo.name
  address_prefixes     = ["10.0.3.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
  delegation {
    name = "fs"
    service_delegation {
      name = "Microsoft.DBforMySQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
  depends_on = [azurerm_virtual_network.snapvideo]
}

resource "azurerm_lb" "backend" {
  name                = "belb-${var.customer}-${terraform.workspace}-${var.location}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  frontend_ip_configuration {
    name               = "beip-${var.customer}-${terraform.workspace}-${var.location}"
    subnet_id          = azurerm_subnet.backend.id
    private_ip_address = "10.0.2.240"
  }
}

resource "azurerm_lb_nat_rule" "backend" {
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.backend.id
  name                           = "belbrule-${var.customer}-${terraform.workspace}-${var.location}"
  protocol                       = "Tcp"
  frontend_port                  = 8080
  backend_port                   = 8080
  frontend_ip_configuration_name = "beip-${var.customer}-${terraform.workspace}-${var.location}"
}

resource "azurerm_network_interface_nat_rule_association" "backend" {
  network_interface_id  = azurerm_network_interface.snapvideobackend.id
  ip_configuration_name = "internal"
  nat_rule_id           = azurerm_lb_nat_rule.backend.id
}


resource "azurerm_public_ip" "web" {
  name                = "ip-web-${var.customer}-${terraform.workspace}-${var.location}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Dynamic"
}

locals {
  backend_address_pool_name      = "${azurerm_virtual_network.snapvideo.name}-beap"
  frontend_port_name             = "${azurerm_virtual_network.snapvideo.name}-feport"
  frontend_ip_configuration_name = "${azurerm_virtual_network.snapvideo.name}-feip"
  http_setting_name              = "${azurerm_virtual_network.snapvideo.name}-be-htst"
  listener_name                  = "${azurerm_virtual_network.snapvideo.name}-httplstn"
  request_routing_rule_name      = "${azurerm_virtual_network.snapvideo.name}-rqrt"
}

resource "azurerm_application_gateway" "network" {
  name                = "aag-${var.customer}-${terraform.workspace}-${var.location}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "gateway-ipconfig-${var.customer}-${terraform.workspace}-${var.location}"
    subnet_id = azurerm_subnet.aag.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.web.id
  }

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    path                  = "/path1/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }
}