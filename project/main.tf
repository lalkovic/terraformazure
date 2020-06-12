# define provider here
provider "azurerm" {
  version = "2.2.0"
  features {}
}

provider "random" {
  version = "2.2"
}

module "location_canadacentral" {
  source = "./location"
  
  geo_location                  = "canadacentral"
  rg_name                       = "${var.rg_name}-canadacentral"
  resource_prefix               = "${var.resource_prefix}-canadacentral"
  project_address_space         = "1.0.0.0/22"
  project_name                  = var.project_name
  environment                   = var.environment
  project_count                 = var.project_count
  project_subnets               = {
    web-server                  = "1.0.1.0/24"
    AzureBastionSubnet          = "1.0.2.0/24"
  }
  terraform_script_version      = var.terraform_script_version
  admin_password                = data.azurerm_key_vault_secret.admin_password.value 
  domain_name_label             = var.domain_name_label
  vm_name                       = "ccvm"
}

module "location_canadaeast" {
  source = "./location"
  
  geo_location                  = "canadaeast"
  rg_name                       = "${var.rg_name}-canadaeast"
  resource_prefix               = "${var.resource_prefix}-canadaeast"
  project_address_space         = "2.0.0.0/22"
  project_name                  = var.project_name
  environment                   = var.environment
  project_count                 = var.project_count
  project_subnets               = {
    web-server                  = "2.0.1.0/24"
    AzureBastionSubnet          = "2.0.2.0/24"
  }
  terraform_script_version      = var.terraform_script_version
  admin_password                = data.azurerm_key_vault_secret.admin_password.value 
  domain_name_label             = var.domain_name_label
  vm_name                       = "cevm"
}

resource "azurerm_resource_group" "global_rg" {
  name     = "traffic-manager-rg"
  location = "canadacentral"
}

resource "azurerm_traffic_manager_profile" "traffic_manager" {
  name                   = "${var.resource_prefix}-traffic-manager"
  resource_group_name    = azurerm_resource_group.global_rg.name
  traffic_routing_method = "Weighted"

  dns_config {
    relative_name = var.domain_name_label
    ttl           = 100
  }

  monitor_config {
    protocol = "http"
    port     = 80
    path     = "/"
  }
}

resource "azurerm_traffic_manager_endpoint" "traffic_manager_cc" {
  name                = "${var.resource_prefix}-cc-endpoint"
  resource_group_name = azurerm_resource_group.global_rg.name
  profile_name        = azurerm_traffic_manager_profile.traffic_manager.name
  target_resource_id  = module.location_canadacentral.project_lb_public_ip_id
  type                = "azureEndpoints"
  weight              = 100
}

resource "azurerm_traffic_manager_endpoint" "traffic_manager_ce" {
  name                = "${var.resource_prefix}-ce-endpoint"
  resource_group_name = azurerm_resource_group.global_rg.name
  profile_name        = azurerm_traffic_manager_profile.traffic_manager.name
  target_resource_id  = module.location_canadaeast.project_lb_public_ip_id
  type                = "azureEndpoints"
  weight              = 100
}