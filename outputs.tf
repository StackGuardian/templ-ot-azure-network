output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.this.name
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.this.name
}

output "vnet_cidr" {
  description = "Address space of the virtual network"
  value       = one(azurerm_virtual_network.this.address_space)
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = azurerm_subnet.public.id
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = azurerm_subnet.private.id
}

output "public_subnet_cidr" {
  description = "Address range of the public subnet"
  value       = local.public_cidr
}

output "private_subnet_cidr" {
  description = "Address range of the private subnet"
  value       = local.private_cidr
}

output "nat_gateway_id" {
  description = "ID of the NAT gateway, null when it is off"
  value       = one(azurerm_nat_gateway.this[*].id)
}

output "nat_public_ip" {
  description = "Public IP address of the NAT gateway, null when it is off"
  value       = one(azurerm_public_ip.nat[*].ip_address)
}
