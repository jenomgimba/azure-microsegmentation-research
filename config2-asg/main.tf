# Configuration 2 - Application Security Group (ASG) Segmentation
# Workload-level segmentation using ASGs

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  skip_provider_registration = true
}

# Resource Group
resource "azurerm_resource_group" "config2" {
  name     = "rg-segmentation-config2-asg"
  location = "uksouth"
  
  tags = {
    Environment = "Research"
    Configuration = "Config2-ASG"
    Project = "ZeroTrust-Segmentation"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "config2" {
  name                = "vnet-config2"
  address_space       = ["10.2.0.0/16"]
  location            = azurerm_resource_group.config2.location
  resource_group_name = azurerm_resource_group.config2.name
  
  tags = {
    Environment = "Research"
    Configuration = "Config2-ASG"
  }
}

# Subnets - More flexible than Config1
resource "azurerm_subnet" "workloads" {
  name                 = "subnet-workloads"
  resource_group_name  = azurerm_resource_group.config2.name
  virtual_network_name = azurerm_virtual_network.config2.name
  address_prefixes     = ["10.2.1.0/24"]
}

resource "azurerm_subnet" "management" {
  name                 = "subnet-management"
  resource_group_name  = azurerm_resource_group.config2.name
  virtual_network_name = azurerm_virtual_network.config2.name
  address_prefixes     = ["10.2.4.0/24"]
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.config2.name
  virtual_network_name = azurerm_virtual_network.config2.name
  address_prefixes     = ["10.2.255.0/26"]
}

# Application Security Groups
resource "azurerm_application_security_group" "web" {
  name                = "asg-web-servers"
  location            = azurerm_resource_group.config2.location
  resource_group_name = azurerm_resource_group.config2.name
  
  tags = {
    Role = "WebServer"
  }
}

resource "azurerm_application_security_group" "app" {
  name                = "asg-app-servers"
  location            = azurerm_resource_group.config2.location
  resource_group_name = azurerm_resource_group.config2.name
  
  tags = {
    Role = "ApplicationServer"
  }
}

resource "azurerm_application_security_group" "database" {
  name                = "asg-database-servers"
  location            = azurerm_resource_group.config2.location
  resource_group_name = azurerm_resource_group.config2.name
  
  tags = {
    Role = "DatabaseServer"
  }
}

resource "azurerm_application_security_group" "management" {
  name                = "asg-management"
  location            = azurerm_resource_group.config2.location
  resource_group_name = azurerm_resource_group.config2.name
  
  tags = {
    Role = "Management"
  }
}

# NSG for Workloads Subnet - Rules reference ASGs
resource "azurerm_network_security_group" "workloads" {
  name                = "nsg-workloads"
  location            = azurerm_resource_group.config2.location
  resource_group_name = azurerm_resource_group.config2.name
  
  # Allow HTTP/HTTPS to web servers from internet
  security_rule {
    name                                       = "Allow-Web-Inbound"
    priority                                   = 100
    direction                                  = "Inbound"
    access                                     = "Allow"
    protocol                                   = "Tcp"
    source_port_range                          = "*"
    destination_port_ranges                    = ["80", "443"]
    source_address_prefix                      = "*"
    destination_application_security_group_ids = [azurerm_application_security_group.web.id]
  }
  
  # Allow web to app communication
  security_rule {
    name                                       = "Allow-Web-To-App"
    priority                                   = 200
    direction                                  = "Inbound"
    access                                     = "Allow"
    protocol                                   = "Tcp"
    source_port_range                          = "*"
    destination_port_ranges                    = ["80", "443", "8080"]
    source_application_security_group_ids      = [azurerm_application_security_group.web.id]
    destination_application_security_group_ids = [azurerm_application_security_group.app.id]
  }
  
  # Allow app to database communication
  security_rule {
    name                                       = "Allow-App-To-Database"
    priority                                   = 300
    direction                                  = "Inbound"
    access                                     = "Allow"
    protocol                                   = "Tcp"
    source_port_range                          = "*"
    destination_port_ranges                    = ["1433", "3306", "5432"]
    source_application_security_group_ids      = [azurerm_application_security_group.app.id]
    destination_application_security_group_ids = [azurerm_application_security_group.database.id]
  }
  
  # Deny web to database (prevent lateral movement)
  security_rule {
    name                                       = "Deny-Web-To-Database"
    priority                                   = 400
    direction                                  = "Inbound"
    access                                     = "Deny"
    protocol                                   = "*"
    source_port_range                          = "*"
    destination_port_range                     = "*"
    source_application_security_group_ids      = [azurerm_application_security_group.web.id]
    destination_application_security_group_ids = [azurerm_application_security_group.database.id]
  }
  
  # Allow management to all ASGs
  security_rule {
    name                                  = "Allow-Management-Inbound"
    priority                              = 500
    direction                             = "Inbound"
    access                                = "Allow"
    protocol                              = "*"
    source_port_range                     = "*"
    destination_port_range                = "*"
    source_application_security_group_ids = [azurerm_application_security_group.management.id]
    destination_address_prefix            = "*"
  }
  
  tags = {
    Configuration = "Config2-ASG"
  }
}

# NSG for Management Subnet
resource "azurerm_network_security_group" "management" {
  name                = "nsg-management"
  location            = azurerm_resource_group.config2.location
  resource_group_name = azurerm_resource_group.config2.name
  
  # Allow RDP from internet
  security_rule {
    name                       = "Allow-RDP-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  # Allow all outbound to workloads
  security_rule {
    name                       = "Allow-To-Workloads"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "10.2.1.0/24"
  }
  
  tags = {
    Configuration = "Config2-ASG"
  }
}

# Associate NSGs
resource "azurerm_subnet_network_security_group_association" "workloads" {
  subnet_id                 = azurerm_subnet.workloads.id
  network_security_group_id = azurerm_network_security_group.workloads.id
}

resource "azurerm_subnet_network_security_group_association" "management" {
  subnet_id                 = azurerm_subnet.management.id
  network_security_group_id = azurerm_network_security_group.management.id
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "config2" {
  name                = "law-config2"
  location            = azurerm_resource_group.config2.location
  resource_group_name = azurerm_resource_group.config2.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  
  tags = {
    Environment = "Research"
    Configuration = "Config2-ASG"
  }
}

# Storage for flow logs
resource "azurerm_storage_account" "flowlogs" {
  name                     = "stflowlogsconfig2"
  resource_group_name      = azurerm_resource_group.config2.name
  location                 = azurerm_resource_group.config2.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Outputs
output "resource_group_name" {
  value = azurerm_resource_group.config2.name
}

output "subnet_ids" {
  value = {
    workloads  = azurerm_subnet.workloads.id
    management = azurerm_subnet.management.id
  }
}

output "asg_ids" {
  value = {
    web        = azurerm_application_security_group.web.id
    app        = azurerm_application_security_group.app.id
    database   = azurerm_application_security_group.database.id
    management = azurerm_application_security_group.management.id
  }
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.config2.id
}
