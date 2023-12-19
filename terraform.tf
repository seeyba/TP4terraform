module "network" {
 source = "./modules/network"
 virtual_network_name = var.virtual_network_name
 resource_group_name = var.resource_group_name
 localzones = local.zones
 address_space = var.address_space
 virtual_network_subnet_ids = var.subnet_config
subnet_config = var.subnet_config
}
module "VMSS" {
  source = "./modules/VMSS"
  virtual_network_name = var.virtual_network_name
  resource_group_name = var.resource_group_name
  address_space = var.address_space
  virtual_network_subnet_ids = var.virtual_network_subnet_ids
}
module "database" {
  source = "./modules/databases"
  virtual_network_name = var.virtual_network_name
  resource_group_name = var.resource_group_name
}

/*
resource "azurerm_policy_definition" "rg_policy" {
  name         = "only-deploy-in-francecentral"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "my-policy-definition"
  policy_rule  = file("./policy.json")
}
*/
#resource "azurerm_resource_group_policy_assignment" "policy_assignment" {
#  name                 = "rg-policy-assignment"
#  resource_group_id    = azurerm_resource_group.rg.id
#  policy_definition_id = azurerm_policy_definition.rg_policy.id
#}



locals {
  zones = {
    "francecentral" = ["0", "1", "2"]
    "westeurope"    = ["0", "1"]
  }
}
/*
resource "azurerm_subnet" "public_subnets" {
  count                = var.is_multi_az == true ? length(lookup(local.zones, module.network.resource_group.location )) : 1
  name                 = format("pub-subnet-%s", count.index)
  resource_group_name  = module.network.resource_group.name
  virtual_network_name = module.network.vnet.name
  address_prefixes     = tolist([cidrsubnet(var.address_space, 8, count.index + 1)])
}

resource "azurerm_subnet" "private_subnets" {
  count                = var.is_multi_az == true ? length(lookup(local.zones, module.network.resource_group_name.location)) : 1
  name                 = format("priv-subnet-%s", count.index)
  resource_group_name  = module.network.resource_group.name
  virtual_network_name = module.network.vnet.name
  address_prefixes     = tolist([cidrsubnet(var.address_space, 8, count.index + 10)])
  service_endpoints    = ["Microsoft.Storage"]
}
*/


resource "azurerm_public_ip" "public_ips" {
  count               = var.is_multi_az == true ? length(lookup(local.zones, module.network.resource_group_name.location )) : 1
  name                = format("nat-gw-pip-%s", count.index)
  location            = module.network.resource_group.location
  resource_group_name = module.network.resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags = {
    "Environment" = terraform.workspace
  }
  zones = [count.index + 1]
}

resource "azurerm_nat_gateway_public_ip_association" "natgw_pip_assoc" {
  count                = var.is_multi_az == true ? length(lookup(local.zones, module.network.resource_group_name.location)) : 1
  nat_gateway_id       = module.network.nat_gw[count.index].id
  public_ip_address_id = azurerm_public_ip.ips[count.index].id
}

resource "azurerm_subnet_nat_gateway_association" "natgw_subnet_assoc" {
  count          = var.is_multi_az == true ? length(lookup(local.zones, module.network.resource_group.location)) : 1
  subnet_id      = var.virtual_network_subnet_ids [count.index].id
  nat_gateway_id = module.network.nat_gw[count.index].id
}

########## La correction commence ici ##########
/*
resource "azurerm_network_interface" "nic" {
  name                = "vm-nic"
  location            = module.network.resource_group.location
  resource_group_name = module.network.resource_group.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.private_subnets[0].id
    private_ip_address_allocation = "Dynamic"
  }
  tags = {
    "Environment" = terraform.workspace
  }
}



resource "azurerm_linux_virtual_machine_scale_set" "example" {
  name                            = "wordpress-vmss"
  resource_group_name             = module.network.resource_group.name
  location                        = module.network.resource_group.location
  sku                             = "Standard_F2"
  instances                       = 1
  admin_username                  = "adminuser"
  admin_password                  = "Plop09"
  disable_password_authentication = false
  custom_data = base64encode(templatefile("templates/start.sh", {
    nfs_endpoint      = azurerm_storage_account.wordpress_data.primary_blob_host,
    blob_storage_name = "wp-data"
    wordpress_version = "6.3.2"
  }))
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  tags = {
    "Environment" = terraform.workspace
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name                      = "nic"
    primary                   = true
    network_security_group_id = azurerm_network_security_group.example.id

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.private_subnets[0].id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.pool.id]
    }
  }
  identity {
    identity_ids = []
    type         = "SystemAssigned"
  }
}

resource "azurerm_storage_account" "wordpress_data" {
  name                     = "wpdatasjoff"
  resource_group_name      = module.network.resource_group.name
  location                 = module.network.resource_group.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true
  nfsv3_enabled            = true
  tags = {
    "Environment" = terraform.workspace
  }
  network_rules {
    default_action             = "Deny"
    virtual_network_subnet_ids = [azurerm_subnet.private_subnets[0].id]
    ip_rules                   = ["95.176.19.7", "217.128.163.115", "45.88.143.138" , "141.170.218.210"] # METTRE SON IP PUB
  }

}

resource "azurerm_storage_container" "container" {
  name                  = "wp-data"
  storage_account_name  = azurerm_storage_account.wordpress_data.name
  container_access_type = "private"
  depends_on            = [azurerm_storage_account.wordpress_data]
}

resource "azurerm_public_ip" "lb_pip" {
  name                = "PublicIPForLB"
  location            = module.network.resource_group.location
  resource_group_name = module.network.resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "lb" {
  name                = "TestLoadBalancer"
  location            = module.network.resource_group.location
  resource_group_name = module.network.resource_group.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.lb_pip.id
  }
}

resource "azurerm_lb_nat_rule" "http" {
  resource_group_name            = module.network.resource_group.name
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "http"
  protocol                       = "Tcp"
  frontend_port_start            = 80
  frontend_port_end              = 81
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.pool.id
}

resource "azurerm_lb_probe" "probe" {
  loadbalancer_id = azurerm_lb.lb.id
  protocol        = "Http"
  name            = "http-running-probe"
  port            = 80
  request_path    = "/"
}

resource "azurerm_lb_backend_address_pool" "pool" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "BackEndAddressPool"
}

resource "azurerm_network_security_group" "example" {
  name                = "wordpress-nsg"
  location            = module.network.resource_group.location
  resource_group_name = module.network.resource_group.name
  security_rule {
    name                       = "all"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = terraform.workspace
  }
}

resource "azurerm_monitor_autoscale_setting" "example" {
  name                = "myAutoscaleSetting"
  resource_group_name = module.network.resource_group.name
  location            = var.location
  target_resource_id  = .example.id

  profile {
    name = "defaultProfile"

    capacity {
      default = 1
      minimum = 1
      maximum = 2
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.example.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 50
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"
        dimensions {
          name     = "AppName"
          operator = "Equals"
          values   = ["App1"]
        }
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.example.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 50
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }

  notification {
    email {
      send_to_subscription_administrator    = true
      send_to_subscription_co_administrator = true
      custom_emails                         = ["mamadou.coulibalymalle@ynov.com"]
    }
  }
}
*/

resource "azurerm_monitor_action_group" "example" {
  name                = "example"
  resource_group_name = module.network.resource_group.name
  short_name          = "example"
}

resource "azurerm_consumption_budget_resource_group" "example" {
  name              = "example"
  resource_group_id = module.network.resource_group.id

  amount     = 10
  time_grain = "Monthly"

  time_period {
    start_date = "2024-01-01T00:00:00Z"
    end_date   = "2024-07-01T00:00:00Z"
  }

  filter {
    dimension {
      name = "ResourceId"
      values = [
        azurerm_monitor_action_group.example.id,
      ]
    }

    tag {
      name = "foo"
      values = [
        "bar",
        "baz",
      ]
    }
  }

  notification {
    enabled        = true
    threshold      = 90.0
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Forecasted"

    contact_emails = ["mamadou.coulibalymalle@ynov.com"]

    contact_groups = [
      azurerm_monitor_action_group.example.id,
    ]

    contact_roles = [
      "Owner",
    ]
  }

  notification {
    enabled   = true
    threshold = 100.0
    operator  = "GreaterThanOrEqualTo"
    threshold_type = "Actual"
    contact_emails = ["mamadou.coulibalymalle@ynov.com"]
  }
}
