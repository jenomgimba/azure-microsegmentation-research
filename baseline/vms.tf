# Virtual Machines - Web, Application, and Database servers

# Admin credentials
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
  location            = azurerm_resource_group.baseline.location
  resource_group_name = azurerm_resource_group.baseline.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Web Server VMs
resource "azurerm_network_interface" "web" {
  count               = 1
  name                = "nic-web-${count.index + 1}"
  location            = azurerm_resource_group.baseline.location
  resource_group_name = azurerm_resource_group.baseline.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.web[count.index].id
  }

  tags = {
    Role = "WebServer"
    Tier = "Web"
  }
}

resource "azurerm_windows_virtual_machine" "web" {
  count               = 1
  name                = "vm-web-${count.index + 1}"
  resource_group_name = azurerm_resource_group.baseline.name
  location            = azurerm_resource_group.baseline.location
  size                = "Standard_B2as_v2"
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.web[count.index].id,
  ]

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
  
  tags = {
    Role = "WebServer"
    Tier = "Web"
  }
}

resource "azurerm_public_ip" "app" {
  count               = 1
  name                = "pip-app-${count.index + 1}"
  location            = azurerm_resource_group.baseline.location
  resource_group_name = azurerm_resource_group.baseline.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Application Server VMs
resource "azurerm_network_interface" "app" {
  count               = 1
  name                = "nic-app-${count.index + 1}"
  location            = azurerm_resource_group.baseline.location
  resource_group_name = azurerm_resource_group.baseline.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.app[count.index].id
  }

  tags = {
    Role = "ApplicationServer"
    Tier = "Application"
  }
}

resource "azurerm_windows_virtual_machine" "app" {
  count               = 1
  name                = "vm-app-${count.index + 1}"
  resource_group_name = azurerm_resource_group.baseline.name
  location            = azurerm_resource_group.baseline.location
  size                = "Standard_B2as_v2"
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.app[count.index].id,
  ]

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
  
  tags = {
    Role = "ApplicationServer"
    Tier = "Application"
  }
}

# Database Server VMs
resource "azurerm_network_interface" "db" {
  count               = 1
  name                = "nic-db-${count.index + 1}"
  location            = azurerm_resource_group.baseline.location
  resource_group_name = azurerm_resource_group.baseline.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    Role = "DatabaseServer"
    Tier = "Database"
  }
}

resource "azurerm_windows_virtual_machine" "db" {
  count               = 1
  name                = "vm-db-${count.index + 1}"
  resource_group_name = azurerm_resource_group.baseline.name
  location            = azurerm_resource_group.baseline.location
  size                = "Standard_B2as_v2"
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.db[count.index].id,
  ]

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
  
  tags = {
    Role = "DatabaseServer"
    Tier = "Database"
  }
}

# Azure Monitor Agent extensions
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

# VM configuration extensions
resource "azurerm_virtual_machine_extension" "config_web" {
  count                = 1
  name                 = "VMConfiguration"
  virtual_machine_id   = azurerm_windows_virtual_machine.web[count.index].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Unrestricted -Command \"Enable-PSRemoting -Force; Set-Item WSMan:\\localhost\\Client\\TrustedHosts -Value '*' -Force; Set-ExecutionPolicy RemoteSigned -Force; Enable-NetFirewallRule -DisplayName 'File and Printer Sharing (Echo Request - ICMPv4-In)' -ErrorAction SilentlyContinue; New-NetFirewallRule -DisplayName 'Allow ICMPv4-In' -Protocol ICMPv4 -IcmpType 8 -Enabled True -Direction Inbound -Action Allow -ErrorAction SilentlyContinue; Enable-NetFirewallRule -DisplayGroup 'File and Printer Sharing' -ErrorAction SilentlyContinue; Enable-NetFirewallRule -DisplayGroup 'Windows Remote Management' -ErrorAction SilentlyContinue; Restart-Service WinRM\""
  })

  depends_on = [azurerm_virtual_machine_extension.monitor_web]
}

resource "azurerm_virtual_machine_extension" "config_app" {
  count                = 1
  name                 = "VMConfiguration"
  virtual_machine_id   = azurerm_windows_virtual_machine.app[count.index].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Unrestricted -Command \"Enable-PSRemoting -Force; Set-Item WSMan:\\localhost\\Client\\TrustedHosts -Value '*' -Force; Set-ExecutionPolicy RemoteSigned -Force; Enable-NetFirewallRule -DisplayName 'File and Printer Sharing (Echo Request - ICMPv4-In)' -ErrorAction SilentlyContinue; New-NetFirewallRule -DisplayName 'Allow ICMPv4-In' -Protocol ICMPv4 -IcmpType 8 -Enabled True -Direction Inbound -Action Allow -ErrorAction SilentlyContinue; Enable-NetFirewallRule -DisplayGroup 'File and Printer Sharing' -ErrorAction SilentlyContinue; Enable-NetFirewallRule -DisplayGroup 'Windows Remote Management' -ErrorAction SilentlyContinue; Restart-Service WinRM\""
  })

  depends_on = [azurerm_virtual_machine_extension.monitor_app]
}

resource "azurerm_virtual_machine_extension" "config_db" {
  count                = 1
  name                 = "VMConfiguration"
  virtual_machine_id   = azurerm_windows_virtual_machine.db[count.index].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Unrestricted -Command \"Enable-PSRemoting -Force; Set-Item WSMan:\\localhost\\Client\\TrustedHosts -Value '*' -Force; Set-ExecutionPolicy RemoteSigned -Force; Enable-NetFirewallRule -DisplayName 'File and Printer Sharing (Echo Request - ICMPv4-In)' -ErrorAction SilentlyContinue; New-NetFirewallRule -DisplayName 'Allow ICMPv4-In' -Protocol ICMPv4 -IcmpType 8 -Enabled True -Direction Inbound -Action Allow -ErrorAction SilentlyContinue; Enable-NetFirewallRule -DisplayGroup 'File and Printer Sharing' -ErrorAction SilentlyContinue; Enable-NetFirewallRule -DisplayGroup 'Windows Remote Management' -ErrorAction SilentlyContinue; Restart-Service WinRM\""
  })

  depends_on = [azurerm_virtual_machine_extension.monitor_db]
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

# Data Collection Rule Associations
resource "azurerm_monitor_data_collection_rule_association" "web" {
  count                   = 1
  name                    = "dcra-web-${count.index + 1}"
  target_resource_id      = azurerm_windows_virtual_machine.web[count.index].id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.security_events.id
}

resource "azurerm_monitor_data_collection_rule_association" "app" {
  count                   = 1
  name                    = "dcra-app-${count.index + 1}"
  target_resource_id      = azurerm_windows_virtual_machine.app[count.index].id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.security_events.id
}

resource "azurerm_monitor_data_collection_rule_association" "db" {
  count                   = 1
  name                    = "dcra-db-${count.index + 1}"
  target_resource_id      = azurerm_windows_virtual_machine.db[count.index].id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.security_events.id
}
