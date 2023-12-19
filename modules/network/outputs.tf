output "resource_group" {
value = azurerm_resource_group.rg
}
output "vnet" {
value = azurerm_virtual_network.vnet
}
output "nat_gw" {
value = azurerm_nat_gateway.nat_gw
  
}
