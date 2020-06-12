data "terraform_remote_state" "project" {
  backend = "azurerm"
  config = {
    resource_group_name  = "tf-remote-state"
    storage_account_name = "udemylearnlalkovic"
    container_name       = "tfstate"
    key                  = "project.tfstate"
  }
}

