resource "azurerm_windows_virtual_machine_scale_set" "web" {
  name                = "vmss-web"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard_B2ms"
  instances           = 1
  admin_password      = azurerm_key_vault_secret.webpassword.value
  admin_username      = "adminuser"
  
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-core"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "web"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.web.id
    }
  }

tags = {
    "environment"  = "client demo"
    "productowner" = "JohnFox"
    "deployedBy"   = "terraformCloud"
  }

  depends_on = [azurerm_key_vault.kv]
}


resource "azurerm_linux_virtual_machine" "snapvideobackend" {
  name                  = "vm-backend"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.snapvideobackend.id]
  size                  = "Standard_B2ms"
  availability_set_id   = azurerm_availability_set.backend.id
  computer_name         = "vm-backend"
  admin_username        = "testadmin"
  admin_password        = azurerm_key_vault_secret.backendpassword.value
  disable_password_authentication = false

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    name                 = "disk-osBackend-${var.customer}-${terraform.workspace}-${var.location}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  tags = {
    "environment"  = "client demo"
    "productowner" = "JohnFox"
    "deployedBy"   = "terraformCloud"
  }

  depends_on = [azurerm_network_interface.snapvideobackend, azurerm_availability_set.backend, azurerm_key_vault.kv]
}

resource "azurerm_network_interface" "snapvideobackend" {
  name                = "nic-backend-${var.customer}-${terraform.workspace}-${var.location}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.backend.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_availability_set" "backend" {
  name                         = "as-backend-${var.customer}-${terraform.workspace}-${var.location}"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  platform_fault_domain_count  = 3
  platform_update_domain_count = 3
  managed                      = true
}
