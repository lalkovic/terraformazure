locals {
  project_name   = var.environment == "production" ? "${var.project_name}-prd" : "${var.project_name}-dev"
  build_environment = var.environment == "production" ? "production" : "development"
}

#
# define resources
#

# resource group
resource "azurerm_resource_group" "tfaz_rg" {
  name = "${var.resource_prefix}_${var.rg_name}"
  location = var.geo_location

  tags = {
    environment       = local.build_environment
    build_version     = var.terraform_script_version
  }
}

# create VNET - logical isolated network dedicated to current subscription. similar to physical network regarding securiy features.
# you give it address space and can be divided into subnetworks. we can assign network security group (NSG).
# Can configure services like VPN or ExpressRoute (high speed almost direct connectivity to Azure)
resource "azurerm_virtual_network" "tfaz_vnet" {
  name                = "${var.resource_prefix}-vnet"
  location            = var.geo_location
  resource_group_name = azurerm_resource_group.tfaz_rg.name
  address_space       = [var.project_address_space]
}

# create subnet - way of segmenting VNET. Has to be associated with VNET. Address space must be valid subspace of address space of VNET
# provides another security boundary (NSG or ASG - application sec group). ASG can be used if for example we want to allow one app
# to communicate over a specific port. Also used as service endpoint (Microsoft.Storage, Microsoft.SQL...)
resource "azurerm_subnet" "project_subnet" {
  for_each = var.project_subnets
    name                    = each.key
    resource_group_name     = azurerm_resource_group.tfaz_rg.name
    virtual_network_name    = azurerm_virtual_network.tfaz_vnet.name
    address_prefix          = each.value
}


# createt public IP - allows for public access into our env (VM, ...). Static or dynamic
resource "azurerm_public_ip" "project_lb_public_ip" {
  name                  = "${var.resource_prefix}-public-ip"
  resource_group_name   = azurerm_resource_group.tfaz_rg.name
  location              = var.geo_location
  allocation_method     = var.environment == "production" ? "Static" : "Dynamic" #example of conditionals
  domain_name_label     = var.domain_name_label
}

# create network security group - provides traffic control - filters protocols, ips, ports based on source and destination rules. 
# allows traffic between VNETs and between load balancers. can be scoped at various levels 
resource "azurerm_network_security_group" "project_nsg" {
  name                  = "${var.resource_prefix}-nsg"
  resource_group_name   = azurerm_resource_group.tfaz_rg.name
  location              = var.geo_location
}

resource "azurerm_network_security_rule" "project_nsg_rule_rdp" {
  name                        = "RDP Inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range     = "3389"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.tfaz_rg.name
  network_security_group_name = azurerm_network_security_group.project_nsg.name
  count                       = var.environment == "production" ? 0 : 1
}

resource "azurerm_network_security_rule" "project_nsg_rule_http" {
  name                        = "HTTP Inbound"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range     = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.tfaz_rg.name
  network_security_group_name = azurerm_network_security_group.project_nsg.name
}

resource "azurerm_subnet_network_security_group_association" "project_sag" {
  network_security_group_id     = azurerm_network_security_group.project_nsg.id
  subnet_id                     = azurerm_subnet.project_subnet["web-server"].id

}

resource "random_string" "random" {
  length  = 10
  upper   = false
  special = false
  number  = false
}

resource "azurerm_storage_account" "storage_account" {
  name                     = "bootdiags${random_string.random.result}"
  location                 = var.geo_location
  resource_group_name      = azurerm_resource_group.tfaz_rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# scale set
resource "azurerm_virtual_machine_scale_set" "project_server" {
  name                        = "${var.resource_prefix}-scale-set"
  resource_group_name         = azurerm_resource_group.tfaz_rg.name
  location                    = var.geo_location
  upgrade_policy_mode         = "manual"

  sku {
    name                      = "Standard_B1s"
    tier                      = "Standard"
    capacity                  = var.project_count
  }

  storage_profile_image_reference {
    publisher                 = "MicrosoftWindowsServer"
    offer                     = "WindowsServerSemiAnnual"
    sku                       = "Datacenter-Core-1709-smalldisk"
    version                   = "latest"
  }

  storage_profile_os_disk {
    name                      = ""
    caching                   = "ReadWrite"
    managed_disk_type         = "Standard_LRS"
    create_option             = "FromImage"
  }

  os_profile {
    admin_username            = "lalkovic"
    admin_password            = var.admin_password
    computer_name_prefix      = var.vm_name
  }

  os_profile_windows_config {
    provision_vm_agent           = true
    enable_automatic_upgrades    = true
  }

  network_profile {
    name                      = "${var.resource_prefix}-project_network_profile"
    primary                   = true

    ip_configuration {
      name                    = local.project_name
      primary                 = true
      subnet_id               = azurerm_subnet.project_subnet["web-server"].id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.project_lb_backend_pool.id]
    }
  }

  boot_diagnostics {
    enabled             = true
    storage_uri         = azurerm_storage_account.storage_account.primary_blob_endpoint
  }

  extension {
    name                      = "${local.project_name}-extension"
    publisher                 = "Microsoft.Compute"
    type                      = "CustomScriptExtension"
    type_handler_version      = "1.10"

    settings = <<SETTINGS
    {
      "fileUris" : ["https://raw.githubusercontent.com/eltimmo/learning/master/azureInstallWebServer.ps1"],
      "commandToexecute" : "start powershell -ExecutionPolicy Unrestricted -File azureInstallWebServer.ps1"
    }
    SETTINGS
  }
}

resource "azurerm_lb" "project_server_lb" {
  name                        = "${var.resource_prefix}-lb"
  resource_group_name         = azurerm_resource_group.tfaz_rg.name
  location                    = var.geo_location

  frontend_ip_configuration {
    name                      = "${var.resource_prefix}-lb-frontend-ip"
    public_ip_address_id      = azurerm_public_ip.project_lb_public_ip.id
  }            
}

resource "azurerm_lb_backend_address_pool" "project_lb_backend_pool" {
  name                        = "${var.resource_prefix}-lb-backend-pool"
  resource_group_name         = azurerm_resource_group.tfaz_rg.name
  loadbalancer_id             = azurerm_lb.project_server_lb.id
}

resource "azurerm_lb_probe" "project_lb_http_probe" {
  name                        = "${var.resource_prefix}-lb-http-probe"
  resource_group_name         = azurerm_resource_group.tfaz_rg.name
  loadbalancer_id             = azurerm_lb.project_server_lb.id
  protocol                    = "tcp"
  port                        = "80"
}

resource "azurerm_lb_rule" "project_lb_http_rule" {
  name                        = "${var.resource_prefix}-lb-http-rule"
  resource_group_name         = azurerm_resource_group.tfaz_rg.name
  loadbalancer_id             = azurerm_lb.project_server_lb.id
  protocol                    = "tcp"
  frontend_port               = "80"
  backend_port                = "80"

  frontend_ip_configuration_name = "${var.resource_prefix}-lb-frontend-ip"
  probe_id                    = azurerm_lb_probe.project_lb_http_probe.id
  backend_address_pool_id     = azurerm_lb_backend_address_pool.project_lb_backend_pool.id
}
