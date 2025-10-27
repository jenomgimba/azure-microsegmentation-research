# Configuration 1 - Network Security Group Subnet-Level Segmentation
# Part of my MSc research evaluating Azure micro-segmentation
# Multiple subnets with NSG rules controlling inter-subnet traffic
# Tests effectiveness of subnet-based network segmentation

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
resource "azurerm_resource_group" "config1" {
  name     = "rg-segmentation-config1-nsg"
  location = "uksouth"
  
  tags = {
    Environment = "Research"
    Configuration = "Config1-NSG"
    Project = "ZeroTrust-Segmentation"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "config1" {
  name                = "vnet-config1"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.config1.location
  resource_group_name = azurerm_resource_group.config1.name
  
  tags = {
    Environment = "Research"
    Configuration = "Config1-NSG"
  }
}

# Subnets - Separated by tier
resource "azurerm_subnet" "web" {
  name                 = "subnet-web"
  resource_group_name  = azurerm_resource_group.config1.name
  virtual_network_name = azurerm_virtual_network.config1.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_subnet" "app" {
  name                 = "subnet-app"
  resource_group_name  = azurerm_resource_group.config1.name
  virtual_network_name = azurerm_virtual_network.config1.name
  address_prefixes     = ["10.1.2.0/24"]
}

resource "azurerm_subnet" "database" {
  name                 = "subnet-database"
  resource_group_name  = azurerm_resource_group.config1.name
  virtual_network_name = azurerm_virtual_network.config1.name
  address_prefixes     = ["10.1.3.0/24"]
}

resource "azurerm_subnet" "management" {
  name                 = "subnet-management"
  resource_group_name  = azurerm_resource_group.config1.name
  virtual_network_name = azurerm_virtual_network.config1.name
  address_prefixes     = ["10.1.4.0/24"]
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.config1.name
  virtual_network_name = azurerm_virtual_network.config1.name
  address_prefixes     = ["10.1.255.0/26"]
}

# NSG for Web Tier
resource "azurerm_network_security_group" "web" {
  name                = "nsg-web"
  location            = azurerm_resource_group.config1.location
  resource_group_name = azurerm_resource_group.config1.name
  
  # Allow HTTP/HTTPS from internet
  security_rule {
    name                       = "Allow-Web-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  # Allow from management subnet
  security_rule {
    name                       = "Allow-Management-Inbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.1.4.0/24"
    destination_address_prefix = "*"
  }
  
  # Allow to App tier only
  security_rule {
    name                       = "Allow-To-App-Tier"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443", "1433", "3306"]
    source_address_prefix      = "*"
    destination_address_prefix = "10.1.2.0/24"
  }
  
  # Deny direct access to database
  security_rule {
    name                       = "Deny-To-Database"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "10.1.3.0/24"
  }
  
  tags = {
    Tier = "Web"
  }
}

# NSG for App Tier
resource "azurerm_network_security_group" "app" {
  name                = "nsg-app"
  location            = azurerm_resource_group.config1.location
  resource_group_name = azurerm_resource_group.config1.name
  
  # Allow from web tier
  security_rule {
    name                       = "Allow-Web-Tier-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443", "1433", "3306"]
    source_address_prefix      = "10.1.1.0/24"
    destination_address_prefix = "*"
  }
  
  # Allow from management
  security_rule {
    name                       = "Allow-Management-Inbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.1.4.0/24"
    destination_address_prefix = "*"
  }
  
  # Deny from internet
  security_rule {
    name                       = "Deny-Internet-Inbound"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
  
  # Allow to database tier
  security_rule {
    name                       = "Allow-To-Database"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["1433", "3306", "5432"]
    source_address_prefix      = "*"
    destination_address_prefix = "10.1.3.0/24"
  }
  
  # Deny to web tier
  security_rule {
    name                       = "Deny-To-Web"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "10.1.1.0/24"
  }
  
  tags = {
    Tier = "Application"
  }
}

# NSG for Database Tier
resource "azurerm_network_security_group" "database" {
  name                = "nsg-database"
  location            = azurerm_resource_group.config1.location
  resource_group_name = azurerm_resource_group.config1.name
  
  # Allow from app tier only
  security_rule {
    name                       = "Allow-App-Tier-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["1433", "3306", "5432"]
    source_address_prefix      = "10.1.2.0/24"
    destination_address_prefix = "*"
  }
  
  # Allow from management
  security_rule {
    name                       = "Allow-Management-Inbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.1.4.0/24"
    destination_address_prefix = "*"
  }
  
  # Deny from web tier
  security_rule {
    name                       = "Deny-Web-Tier-Inbound"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.1.1.0/24"
    destination_address_prefix = "*"
  }
  
  # Deny from internet
  security_rule {
    name                       = "Deny-Internet-Inbound"
    priority                   = 400
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
  
  # Deny all outbound except DNS
  security_rule {
    name                       = "Allow-DNS-Outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "53"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  tags = {
    Tier = "Database"
  }
}

# NSG for Management Tier
resource "azurerm_network_security_group" "management" {
  name                = "nsg-management"
  location            = azurerm_resource_group.config1.location
  resource_group_name = azurerm_resource_group.config1.name
  
  # Allow RDP from specific IP (replace with your IP)
  security_rule {
    name                       = "Allow-RDP-Admin"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"  # Replace with your public IP
    destination_address_prefix = "*"
  }
  
  # Allow management traffic to all tiers
  security_rule {
    name                       = "Allow-To-All-Tiers"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "10.1.0.0/16"
  }
  
  tags = {
    Tier = "Management"
  }
}

# Associate NSGs with Subnets
resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

resource "azurerm_subnet_network_security_group_association" "database" {
  subnet_id                 = azurerm_subnet.database.id
  network_security_group_id = azurerm_network_security_group.database.id
}

resource "azurerm_subnet_network_security_group_association" "management" {
  subnet_id                 = azurerm_subnet.management.id
  network_security_group_id = azurerm_network_security_group.management.id
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "config1" {
  name                = "law-config1"
  location            = azurerm_resource_group.config1.location
  resource_group_name = azurerm_resource_group.config1.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  
  tags = {
    Environment = "Research"
    Configuration = "Config1-NSG"
  }
}

# Network Watcher Flow Logs for all NSGs
resource "azurerm_storage_account" "flowlogs" {
  name                     = "stflowlogsconfig1"
  resource_group_name      = azurerm_resource_group.config1.name
  location                 = azurerm_resource_group.config1.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Outputs
output "resource_group_name" {
  value = azurerm_resource_group.config1.name
}

output "subnet_ids" {
  value = {
    web        = azurerm_subnet.web.id
    app        = azurerm_subnet.app.id
    database   = azurerm_subnet.database.id
    management = azurerm_subnet.management.id
  }
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.config1.id
}
