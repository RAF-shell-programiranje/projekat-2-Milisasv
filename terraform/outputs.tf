output "app_server_public_ip" {
  value       = azurerm_public_ip.app.ip_address
  description = "Public IP of App Server"
}

output "monitor_server_public_ip" {
  value       = azurerm_public_ip.monitor.ip_address
  description = "Public IP of Monitor Server"
}

output "app_server_private_ip" {
  value       = azurerm_network_interface.app.private_ip_address
  description = "Private IP of App Server"
}

output "monitor_server_private_ip" {
  value       = azurerm_network_interface.monitor.private_ip_address
  description = "Private IP of Monitor Server"
}

output "app_server_ssh_command" {
  value       = "ssh azureuser@${azurerm_public_ip.app.ip_address}"
  description = "SSH command for App Server"
}

output "monitor_server_ssh_command" {
  value       = "ssh azureuser@${azurerm_public_ip.monitor.ip_address}"
  description = "SSH command for Monitor Server"
}

output "resource_group_name" {
  value       = azurerm_resource_group.main.name
  description = "Resource Group name"
}
