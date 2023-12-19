
resource "azurerm_network_interface" "nic" {
  name                = "vm-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.virtual_network_subnet_ids.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = {
    "Environment" = terraform.workspace
  }
}
resource "azurerm_linux_virtual_machine_scale_set" "example" {
  name                            = "wordpress-vmss"
  resource_group_name             = var.resource_group_name
  location                        = var.location
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
      subnet_id                              = var.virtual_network_subnet_ids
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
  resource_group_name      = var.resource_group_name
  location                 = var.location
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
    virtual_network_subnet_ids = [var.virtual_network_subnet_ids]
    ip_rules                   = ["95.176.19.7", "217.128.163.115", "45.88.143.138" , "141.170.218.210" , "92.184.102.26"] # METTRE SON IP PUB
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
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "lb" {
  name                = "TestLoadBalancer"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.lb_pip.id
  }
}

resource "azurerm_lb_nat_rule" "http" {
  resource_group_name            = var.resource_group_name
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
  location            = var.location
  resource_group_name = var.resource_group_name
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
  resource_group_name = var.resource_group_name
  location            = var.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.example.id

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
