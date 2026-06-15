output "vnet_id" {
  value = azurerm_virtual_network.hub.id
}

output "aks_subnet_id" {
  value = azurerm_subnet.aks.id
}

output "endpoints_subnet_id" {
  value = azurerm_subnet.endpoints.id
}

output "mgmt_subnet_id" {
  value = azurerm_subnet.mgmt.id
}