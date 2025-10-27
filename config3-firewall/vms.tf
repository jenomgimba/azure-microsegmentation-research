# Virtual Machines for Configuration 3 (same as Config 2 but different subnets)
# 3 VMs: 1 web, 1 app, 1 database

variable "admin_username" {
  type    = string
  default = "azureadmin"
}

variable "admin_password" {
  type      = string
  sensitive = true
  default   = "P@ssw0rd123!ComplexP@ss"
}

# Public IPs
resource "azurerm_public_ip" "web" {
  count               = 1
  name                = "pip-web-${count.index + 1}"
  location            = azurerm_resource_group.config3.location
  resource_group_name = azurerm_resource_group.config3.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "app" {
  count               = 1
  name                = "pip-app-${count.index + 1}"
  location            = azurerm_resource_group.config3.location
  resource_group_name = azurerm_resource_group.config3.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Web Server VMs
resource "azurerm_network_interface" "web" {
  count               = 1
  name                = "nic-web-${count.index + 1}"
  location            = azurerm_resource_group.config3.location
  resource_group_name = azurerm_resource_group.config3.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.web[count.index].id
    application_security_group_ids = [azurerm_application_security_group.web.id]
  }
  
  tags = { Role = "WebServer" }
}

resource "azurerm_windows_virtual_machine" "web" {
  count               = 1
  name                = "vm-web-${count.index + 1}"
  resource_group_name = azurerm_resource_group.config3.name
  location            = azurerm_resource_group.config3.location
  size                = "Standard_B2as_v2"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  
  network_interface_ids = [azurerm_network_interface.web[count.index].id]
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
  
  tags = { Role = "WebServer" }
}

# Application Server VMs
resource "azurerm_network_interface" "app" {
  count               = 1
  name                = "nic-app-${count.index + 1}"
  location            = azurerm_resource_group.config3.location
  resource_group_name = azurerm_resource_group.config3.name
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.app.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.app[count.index].id
    application_security_group_ids = [azurerm_application_security_group.app.id]
  }
  
  tags = { Role = "ApplicationServer" }
}

resource "azurerm_windows_virtual_machine" "app" {
  count               = 1
  name                = "vm-app-${count.index + 1}"
  resource_group_name = azurerm_resource_group.config3.name
  location            = azurerm_resource_group.config3.location
  size                = "Standard_B2as_v2"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  
  network_interface_ids = [azurerm_network_interface.app[count.index].id]
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
  
  tags = { Role = "ApplicationServer" }
}

# Database Server VMs
resource "azurerm_network_interface" "db" {
  count               = 1
  name                = "nic-db-${count.index + 1}"
  location            = azurerm_resource_group.config3.location
  resource_group_name = azurerm_resource_group.config3.name
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.database.id
    private_ip_address_allocation = "Dynamic"
    application_security_group_ids = [azurerm_application_security_group.database.id]
  }
  
  tags = { Role = "DatabaseServer" }
}

resource "azurerm_windows_virtual_machine" "db" {
  count               = 1
  name                = "vm-db-${count.index + 1}"
  resource_group_name = azurerm_resource_group.config3.name
  location            = azurerm_resource_group.config3.location
  size                = "Standard_B2as_v2"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  
  network_interface_ids = [azurerm_network_interface.db[count.index].id]
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
  
  tags = { Role = "DatabaseServer" }
}

# Monitor agents (abbreviated for brevity - same pattern as other configs)
resource "azurerm_virtual_machine_extension" "monitor_web" {
  count                      = 1
  name                       = "AzureMonitorWindowsAgent"
  virtual_machine_id         = azurerm_windows_virtual_machine.web[count.index].id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
}

resource "azurerm_virtual_machine_extension" "monitor_app" {
  count                      = 1
  name                       = "AzureMonitorWindowsAgent"
  virtual_machine_id         = azurerm_windows_virtual_machine.app[count.index].id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
}

resource "azurerm_virtual_machine_extension" "monitor_db" {
  count                      = 1
  name                       = "AzureMonitorWindowsAgent"
  virtual_machine_id         = azurerm_windows_virtual_machine.db[count.index].id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
}


# Outputs
output "web_vm_ids" {
  value = azurerm_windows_virtual_machine.web[*].id
}

output "app_vm_ids" {
  value = azurerm_windows_virtual_machine.app[*].id
}

output "db_vm_ids" {
  value = azurerm_windows_virtual_machine.db[*].id
}

output "web_public_ip" {
  value = azurerm_public_ip.web[*].ip_address
  description = "Public IP for Web VM (RDP access)"
}

output "app_public_ip" {
  value = azurerm_public_ip.app[*].ip_address
  description = "Public IP for App VM (RDP access)"
}
