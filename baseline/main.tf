# Baseline Configuration - Single flat network with traditional perimeter security

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id                = "206290e4-7213-49f1-baa4-307c7658e100"
  resource_provider_registrations = "none"
}

# Resource Group
resource "azurerm_resource_group" "baseline" {
  name     = "rg-segmentation-baseline"
  location = "uksouth"
  
  tags = {
    Environment = "Research"
    Configuration = "Baseline"
  }
}

# Virtual Network
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

# Main Subnet
resource "azurerm_subnet" "main" {
  name                 = "subnet-main"
  resource_group_name  = azurerm_resource_group.baseline.name
  virtual_network_name = azurerm_virtual_network.baseline.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Security Group
resource "azurerm_network_security_group" "baseline" {
  name                = "nsg-baseline-permissive"
  location            = azurerm_resource_group.baseline.location
  resource_group_name = azurerm_resource_group.baseline.name
  
  # Allow RDP
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

# Log Analytics Workspace
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

# Azure Sentinel
resource "azurerm_log_analytics_solution" "sentinel" {
  solution_name         = "SecurityInsights"
  location              = azurerm_resource_group.baseline.location
  resource_group_name   = azurerm_resource_group.baseline.name
  workspace_resource_id = azurerm_log_analytics_workspace.baseline.id
  workspace_name        = azurerm_log_analytics_workspace.baseline.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/SecurityInsights"
  }

  tags = {
    Environment = "Research"
    Configuration = "Baseline"
  }
}

# Storage for flow logs
resource "azurerm_storage_account" "flowlogs" {
  name                     = "stflowlogsbaseline"
  resource_group_name      = azurerm_resource_group.baseline.name
  location                 = azurerm_resource_group.baseline.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    Environment = "Research"
    Configuration = "Baseline"
  }
}

# VNet Flow Logs
resource "azurerm_network_watcher_flow_log" "baseline_vnet" {
  name                 = "flowlog-vnet-baseline"
  network_watcher_name = "NetworkWatcher_uksouth"
  resource_group_name  = "NetworkWatcherRG"

  target_resource_id = azurerm_virtual_network.baseline.id
  storage_account_id = azurerm_storage_account.flowlogs.id
  enabled            = true
  version            = 2

  retention_policy {
    enabled = true
    days    = 7
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = azurerm_log_analytics_workspace.baseline.workspace_id
    workspace_region      = azurerm_log_analytics_workspace.baseline.location
    workspace_resource_id = azurerm_log_analytics_workspace.baseline.id
    interval_in_minutes   = 10
  }

  tags = {
    Environment = "Research"
    Configuration = "Baseline"
  }
}

# Data Collection Rule for security events
resource "azurerm_monitor_data_collection_rule" "security_events" {
  name                = "dcr-security-events-baseline"
  resource_group_name = azurerm_resource_group.baseline.name
  location            = azurerm_resource_group.baseline.location

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.baseline.id
      name                  = "destination-log-analytics"
    }
  }

  data_flow {
    streams      = ["Microsoft-SecurityEvent"]
    destinations = ["destination-log-analytics"]
  }

  data_sources {
    windows_event_log {
      streams = ["Microsoft-SecurityEvent"]
      name    = "eventLogsDataSource"
      x_path_queries = [
        "Security!*[System[(EventID=4624 or EventID=4625 or EventID=4648 or EventID=4672 or EventID=4720 or EventID=4732 or EventID=4776 or EventID=5140 or EventID=5145)]]"
      ]
    }
  }

  tags = {
    Environment   = "Research"
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
