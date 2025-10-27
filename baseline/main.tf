# Baseline Configuration - Traditional Perimeter Security
# Part of my MSc research evaluating Azure micro-segmentation
# This configuration represents traditional security with a single flat network
# Used as the reference baseline for comparison with segmented configurations

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
resource "azurerm_resource_group" "baseline" {
  name     = "rg-segmentation-baseline"
  location = "uksouth"
  
  tags = {
    Environment = "Research"
    Configuration = "Baseline"
    Project = "ZeroTrust-Segmentation"
  }
}

# Virtual Network - Single flat network
resource "azurerm_virtual_network" "baseline" {
  name                = "vnet-baseline"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.baseline.location
  resource_group_name = azurerm_resource_group.baseline.name
  
  tags = {
    Environment = "Research"
    Configuration = "Baseline"
  }
}

# Single Subnet - All VMs in one subnet (flat network)
resource "azurerm_subnet" "main" {
  name                 = "subnet-main"
  resource_group_name  = azurerm_resource_group.baseline.name
  virtual_network_name = azurerm_virtual_network.baseline.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Azure Firewall Subnet (required for Azure Firewall)
resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.baseline.name
  virtual_network_name = azurerm_virtual_network.baseline.name
  address_prefixes     = ["10.0.255.0/26"]
}

# Network Security Group - Permissive (allows internal traffic)
resource "azurerm_network_security_group" "baseline" {
  name                = "nsg-baseline-permissive"
  location            = azurerm_resource_group.baseline.location
  resource_group_name = azurerm_resource_group.baseline.name
  
  # Allow RDP from internet (for management)
  security_rule {
    name                       = "Allow-RDP-Internet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  # Allow all internal traffic
  security_rule {
    name                       = "Allow-Internal-All"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "10.0.0.0/16"
  }
  
  # Allow HTTP/HTTPS inbound
  security_rule {
    name                       = "Allow-Web-Inbound"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  tags = {
    Environment = "Research"
    Configuration = "Baseline"
  }
}

# Associate NSG with subnet
resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.baseline.id
}

# Public IP for Azure Firewall
resource "azurerm_public_ip" "firewall" {
  name                = "pip-firewall-baseline"
  location            = azurerm_resource_group.baseline.location
  resource_group_name = azurerm_resource_group.baseline.name
  allocation_method   = "Static"
  sku                 = "Standard"
  
  tags = {
    Environment = "Research"
    Configuration = "Baseline"
  }
}

# Azure Firewall - Basic perimeter protection
resource "azurerm_firewall" "baseline" {
  name                = "afw-baseline"
  location            = azurerm_resource_group.baseline.location
  resource_group_name = azurerm_resource_group.baseline.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  
  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
  
  tags = {
    Environment = "Research"
    Configuration = "Baseline"
  }
}

# Firewall Network Rule - Allow outbound internet
resource "azurerm_firewall_network_rule_collection" "baseline" {
  name                = "netrc-baseline-outbound"
  azure_firewall_name = azurerm_firewall.baseline.name
  resource_group_name = azurerm_resource_group.baseline.name
  priority            = 100
  action              = "Allow"
  
  rule {
    name = "Allow-Outbound-Internet"
    source_addresses = ["10.0.0.0/16"]
    destination_ports = ["*"]
    destination_addresses = ["*"]
    protocols = ["Any"]
  }
}

# Log Analytics Workspace for monitoring
resource "azurerm_log_analytics_workspace" "baseline" {
  name                = "law-baseline"
  location            = azurerm_resource_group.baseline.location
  resource_group_name = azurerm_resource_group.baseline.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  
  tags = {
    Environment = "Research"
    Configuration = "Baseline"
  }
}

# Outputs
output "resource_group_name" {
  value = azurerm_resource_group.baseline.name
}

output "virtual_network_name" {
  value = azurerm_virtual_network.baseline.name
}

output "subnet_id" {
  value = azurerm_subnet.main.id
}

output "nsg_id" {
  value = azurerm_network_security_group.baseline.id
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.baseline.id
}
