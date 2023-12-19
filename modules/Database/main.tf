resource "azurerm_private_dns_zone" "example" {
  name                = "mysql.database.azure"
  resource_group_name = var.database_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "example" {
  name                  = "VnetZone"
  private_dns_zone_name = azurerm_private_dns_zone.example.name
  virtual_network_id    = var.virtual_network_id
  resource_group_name   = var.resource_group_name
}

resource "azurerm_mysql_flexible_server" "example" {
  name                   = "example-fs"
  resource_group_name    = var.resource_group_name
  location               = var.location 
  administrator_login    = "psqladmin"
  administrator_password = "H@Sh1CoR3!"
  backup_retention_days  = 7
  delegated_subnet_id    = var.virtual_network_id
  private_dns_zone_id    = azurerm_private_dns_zone.example.id
  sku_name               = "GP_Standard_D2ds_v4"

  depends_on = [azurerm_private_dns_zone_virtual_network_link.example]
}