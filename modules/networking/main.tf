resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub-ztp"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = ["10.10.0.0/16"]
  tags                = var.common_tags
}

# AKS nodes + pods (Azure CNI)
resource "azurerm_subnet" "aks" {
  name                 = "subnet-aks"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.10.0.0/20"]
  service_endpoints    = ["Microsoft.KeyVault"]
}

# Private endpoints (ACR, Key Vault)
resource "azurerm_subnet" "endpoints" {
  name                 = "subnet-endpoints"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.10.16.0/24"]

  private_endpoint_network_policies = "Enabled"
}

# Management / bastion-style access for break-glass demos
resource "azurerm_subnet" "mgmt" {
  name                 = "subnet-mgmt"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.10.17.0/24"]
}

resource "azurerm_network_security_group" "aks" {
  name                = "nsg-aks-ztp"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.common_tags

  security_rule {
    name                       = "AllowVnetInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "DenyInternetInboundToNodes"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "endpoints" {
  name                = "nsg-endpoints-ztp"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.common_tags

  security_rule {
    name                       = "AllowVnetInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

resource "azurerm_subnet_network_security_group_association" "endpoints" {
  subnet_id                 = azurerm_subnet.endpoints.id
  network_security_group_id = azurerm_network_security_group.endpoints.id
}