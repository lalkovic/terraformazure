terraform {
  backend "azurerm" {
    resource_group_name     = "tf-remote-state"
    storage_account_name    = "udemylearnlalkovic"
    container_name          = "tfstate"
    key                     = "project.tfstate"
  }
}