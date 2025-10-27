# Configuration 3 - Azure Firewall Enhanced Segmentation
# NSG + ASG + Azure Firewall (defense in depth)

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
resource "azurerm_resource_group" "config3" {
  name     = "rg-segmentation-config3-firewall"
  location = "uksouth"
  
  tags = {
    Environment = "Research"
    Configuration = "Config3-Firewall"
    Project = "ZeroTrust-Segmentation"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "config3" {
  name                = "vnet-config3"
  address_space       = ["10.3.0.0/16"]
  location            = azurerm_resource_group.config3.location
  resource_group_name = azurerm_resource_group.config3.name
  
  tags = {
    Environment = "Research"
    Configuration = "Config3-Firewall"
  }
}

# Subnets
resource "azurerm_subnet" "web" {
  name                 = "subnet-web"
  resource_group_name  = azurerm_resource_group.config3.name
  virtual_network_name = azurerm_virtual_network.config3.name
  address_prefixes     = ["10.3.1.0/24"]
}

resource "azurerm_subnet" "app" {
  name                 = "subnet-app"
  resource_group_name  = azurerm_resource_group.config3.name
  virtual_network_name = azurerm_virtual_network.config3.name
  address_prefixes     = ["10.3.2.0/24"]
}

resource "azurerm_subnet" "database" {
  name                 = "subnet-database"
  resource_group_name  = azurerm_resource_group.config3.name
  virtual_network_name = azurerm_virtual_network.config3.name
  address_prefixes     = ["10.3.3.0/24"]
}

resource "azurerm_subnet" "management" {
  name                 = "subnet-management"
  resource_group_name  = azurerm_resource_group.config3.name
  virtual_network_name = azurerm_virtual_network.config3.name
  address_prefixes     = ["10.3.4.0/24"]
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.config3.name
  virtual_network_name = azurerm_virtual_network.config3.name
  address_prefixes     = ["10.3.255.0/26"]
}

# Application Security Groups
resource "azurerm_application_security_group" "web" {
  name                = "asg-web-servers"
  location            = azurerm_resource_group.config3.location
  resource_group_name = azurerm_resource_group.config3.name
  
  tags = {
    Role = "WebServer"
  }
}

resource "azurerm_application_security_group" "app" {
  name                = "asg-app-servers"
  location            = azurerm_resource_group.config3.location
  resource_group_name = azurerm_resource_group.config3.name
  
  tags = {
    Role = "ApplicationServer"
  }
}

resource "azurerm_application_security_group" "database" {
  name                = "asg-database-servers"
  location            = azurerm_resource_group.config3.location
  resource_group_name = azurerm_resource_group.config3.name
  
  tags = {
    Role = "DatabaseServer"
  }
}

resource "azurerm_application_security_group" "management" {
  name                = "asg-management"
  location            = azurerm_resource_group.config3.location
  resource_group_name = azurerm_resource_group.config3.name
  
  tags = {
    Role = "Management"
  }
}

# NSG for Web Tier
resource "azurerm_network_security_group" "web" {
  name                = "nsg-web"
  location            = azurerm_resource_group.config3.location
  resource_group_name = azurerm_resource_group.config3.name
  
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
  
  # Allow from firewall subnet
  security_rule {
    name                       = "Allow-From-Firewall"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.3.255.0/26"
    destination_address_prefix = "*"
  }
  
  # Force all inter-tier traffic through firewall
  security_rule {
    name                       = "Deny-Direct-To-Other-Tiers"
    priority                   = 300
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "10.3.0.0/16"
  }
  
  # Allow to firewall
  security_rule {
    name                       = "Allow-To-Firewall"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "10.3.255.0/26"
  }
  
  tags = {
    Tier = "Web"
  }
}

# NSG for App Tier
resource "azurerm_network_security_group" "app" {
  name                = "nsg-app"
  location            = azurerm_resource_group.config3.location
  resource_group_name = azurerm_resource_group.config3.name
  
  # Allow from firewall only
  security_rule {
    name                       = "Allow-From-Firewall"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.3.255.0/26"
    destination_address_prefix = "*"
  }
  
  # Deny from internet
  security_rule {
    name                       = "Deny-Internet-Inbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
  
  # Allow to firewall
  security_rule {
    name                       = "Allow-To-Firewall"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "10.3.255.0/26"
  }
  
  tags = {
    Tier = "Application"
  }
}

# NSG for Database Tier
resource "azurerm_network_security_group" "database" {
  name                = "nsg-database"
  location            = azurerm_resource_group.config3.location
  resource_group_name = azurerm_resource_group.config3.name
  
  # Allow from firewall only
  security_rule {
    name                       = "Allow-From-Firewall"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["1433", "3306", "5432"]
    source_address_prefix      = "10.3.255.0/26"
    destination_address_prefix = "*"
  }
  
  # Deny all other inbound
  security_rule {
    name                       = "Deny-All-Other-Inbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  # Allow DNS only
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

# NSG for Management
resource "azurerm_network_security_group" "management" {
  name                = "nsg-management"
  location            = azurerm_resource_group.config3.location
  resource_group_name = azurerm_resource_group.config3.name
  
  # Allow RDP
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
  
  # Allow all to firewall
  security_rule {
    name                       = "Allow-To-Firewall"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "10.3.255.0/26"
  }
  
  tags = {
    Tier = "Management"
  }
}

# Associate NSGs
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

# Public IP for Azure Firewall
resource "azurerm_public_ip" "firewall" {
  name                = "pip-firewall-config3"
  location            = azurerm_resource_group.config3.location
  resource_group_name = azurerm_resource_group.config3.name
  allocation_method   = "Static"
  sku                 = "Standard"
  
  tags = {
    Configuration = "Config3-Firewall"
  }
}

# Azure Firewall
resource "azurerm_firewall" "config3" {
  name                = "afw-config3"
  location            = azurerm_resource_group.config3.location
  resource_group_name = azurerm_resource_group.config3.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  threat_intel_mode   = "Alert"
  
  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
  
  tags = {
    Configuration = "Config3-Firewall"
  }
}

# Firewall Network Rules - Inter-tier communication
resource "azurerm_firewall_network_rule_collection" "inter_tier" {
  name                = "netrc-inter-tier"
  azure_firewall_name = azurerm_firewall.config3.name
  resource_group_name = azurerm_resource_group.config3.name
  priority            = 100
  action              = "Allow"
  
  # Web to App
  rule {
    name                  = "Web-To-App"
    source_addresses      = ["10.3.1.0/24"]
    destination_ports     = ["80", "443", "8080"]
    destination_addresses = ["10.3.2.0/24"]
    protocols             = ["TCP"]
  }
  
  # App to Database
  rule {
    name                  = "App-To-Database"
    source_addresses      = ["10.3.2.0/24"]
    destination_ports     = ["1433", "3306", "5432"]
    destination_addresses = ["10.3.3.0/24"]
    protocols             = ["TCP"]
  }
  
  # Management to all
  rule {
    name                  = "Management-To-All"
    source_addresses      = ["10.3.4.0/24"]
    destination_ports     = ["*"]
    destination_addresses = ["10.3.0.0/16"]
    protocols             = ["Any"]
  }
  
  # DNS
  rule {
    name                  = "Allow-DNS"
    source_addresses      = ["10.3.0.0/16"]
    destination_ports     = ["53"]
    destination_addresses = ["*"]
    protocols             = ["UDP"]
  }
}

# Firewall Application Rules - FQDN filtering
resource "azurerm_firewall_application_rule_collection" "outbound" {
  name                = "apprc-outbound"
  azure_firewall_name = azurerm_firewall.config3.name
  resource_group_name = azurerm_resource_group.config3.name
  priority            = 200
  action              = "Allow"
  
  # Allow Windows Update
  rule {
    name             = "Allow-Windows-Update"
    source_addresses = ["10.3.0.0/16"]
    
    target_fqdns = [
      "*.windowsupdate.microsoft.com",
      "*.update.microsoft.com",
      "*.windowsupdate.com",
      "download.microsoft.com"
    ]
    
    protocol {
      port = "80"
      type = "Http"
    }
    
    protocol {
      port = "443"
      type = "Https"
    }
  }
  
  # Allow Azure services
  rule {
    name             = "Allow-Azure-Services"
    source_addresses = ["10.3.0.0/16"]
    
    target_fqdns = [
      "*.azure.com",
      "*.microsoft.com"
    ]
    
    protocol {
      port = "443"
      type = "Https"
    }
  }
}

# Deny rule for web to database (explicit block)
resource "azurerm_firewall_network_rule_collection" "deny_rules" {
  name                = "netrc-deny"
  azure_firewall_name = azurerm_firewall.config3.name
  resource_group_name = azurerm_resource_group.config3.name
  priority            = 500
  action              = "Deny"
  
  # Explicitly block web to database
  rule {
    name                  = "Deny-Web-To-Database"
    source_addresses      = ["10.3.1.0/24"]
    destination_ports     = ["*"]
    destination_addresses = ["10.3.3.0/24"]
    protocols             = ["Any"]
  }
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "config3" {
  name                = "law-config3"
  location            = azurerm_resource_group.config3.location
  resource_group_name = azurerm_resource_group.config3.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  
  tags = {
    Environment = "Research"
    Configuration = "Config3-Firewall"
  }
}

# Firewall Diagnostics
resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name                       = "firewall-diagnostics"
  target_resource_id         = azurerm_firewall.config3.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.config3.id
  
  enabled_log {
    category = "AzureFirewallApplicationRule"
  }
  
  enabled_log {
    category = "AzureFirewallNetworkRule"
  }
  
  enabled_log {
    category = "AzureFirewallDnsProxy"
  }
  
  metric {
    category = "AllMetrics"
  }
}

# Storage for flow logs
resource "azurerm_storage_account" "flowlogs" {
  name                     = "stflowlogsconfig3"
  resource_group_name      = azurerm_resource_group.config3.name
  location                 = azurerm_resource_group.config3.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Outputs
output "resource_group_name" {
  value = azurerm_resource_group.config3.name
}

output "firewall_private_ip" {
  value = azurerm_firewall.config3.ip_configuration[0].private_ip_address
}

output "subnet_ids" {
  value = {
    web        = azurerm_subnet.web.id
    app        = azurerm_subnet.app.id
    database   = azurerm_subnet.database.id
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
  value = azurerm_log_analytics_workspace.config3.id
}
