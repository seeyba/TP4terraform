resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet${trim(azurerm_resource_group.rg.name,"rg")}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = tolist([var.address_space])

  tags = {
    Environment = terraform.workspace
  }
}
resource "azurerm_subnet" "public_subnets" {
  count                = var.is_multi_az == true ? length(lookup(var.localzones, var.resource_group_name )) : 1
  name                 = format("pub-subnet-%s", count.index)
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.virtual_network_name
  address_prefixes     = tolist([cidrsubnet(var.address_space, 8, count.index + 1)])
}

resource "azurerm_nat_gateway" "nat_gw" {
  count                   = var.is_multi_az == true ? length(lookup(var.localzones, var.resource_group_name )) : 1
  name                    = format("nat-gw-%s", count.index)
  location                = var.location
  resource_group_name     = var.resource_group_name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  zones                   = [count.index + 1]
  tags = {
    "Environment" = terraform.workspace
  }
}

resource "azurerm_subnet" "private_subnets" {
  count                = var.is_multi_az == true ? length(lookup(var.localzones, var.resource_group_name )) : 1
  name                 = format("priv-subnet-%s", count.index)
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_resource_group.rg.name
  address_prefixes     = tolist([cidrsubnet(var.address_space, 8, count.index + 10)])
  service_endpoints    = ["Microsoft.Storage"]
}