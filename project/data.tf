data "azurerm_key_vault" "key_vault" { 
  name                  = "learntf-vault-lalkovic"
  resource_group_name   = "tf-remote-state"
}

data "azurerm_key_vault_secret" "admin_password" { 
  name                  = "admin-password"
  key_vault_id          = data.azurerm_key_vault.key_vault.id
}