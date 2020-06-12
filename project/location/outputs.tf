output "project_lb_public_ip_id" {
  value = azurerm_public_ip.project_lb_public_ip.id
}

output "bastion_host_subnet" {
  value = azurerm_subnet.project_subnet["AzureBastionSubnet"].id
}