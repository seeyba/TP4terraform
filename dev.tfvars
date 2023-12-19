address_space       = "10.32.0.0/16"
resource_group_name = "rg-dev"
subnet_config = {
  "pub01"  = "10.32.1.0/24"
  "priv01" = "10.32.10.0/24"
}
virtual_network_name = "vnet"