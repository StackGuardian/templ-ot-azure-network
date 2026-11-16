resource "azurerm_virtual_network" "this" {
  name                = "${var.name_prefix}-vnet"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.advanced_settings.vnet_cidr]
  tags                = local.tags
}

# Azure subnets have no type. The public subnet is the one where users may attach public IPs.
resource "azurerm_subnet" "public" {
  name                 = "public"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.public_cidr]
}

# No default outbound access: the internet is reachable only through the NAT gateway, if it is on.
resource "azurerm_subnet" "private" {
  name                            = "private"
  resource_group_name             = azurerm_resource_group.this.name
  virtual_network_name            = azurerm_virtual_network.this.name
  address_prefixes                = [local.private_cidr]
  default_outbound_access_enabled = false
}

# One NSG per subnet. Azure already blocks inbound traffic from the internet by default,
# the explicit rule makes that visible and keeps it when users add allow rules with a lower priority number.
resource "azurerm_network_security_group" "this" {
  for_each = toset(["public", "private"])

  name                = "${var.name_prefix}-${each.key}-nsg"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_network_security_rule" "deny_internet_inbound" {
  for_each = azurerm_network_security_group.this

  name                        = "deny-internet-inbound"
  priority                    = 4000
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_address_prefix       = "Internet"
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = each.value.name
}

resource "azurerm_subnet_network_security_group_association" "public" {
  subnet_id                 = azurerm_subnet.public.id
  network_security_group_id = azurerm_network_security_group.this["public"].id

  depends_on = [azurerm_network_security_rule.deny_internet_inbound]
}

resource "azurerm_subnet_network_security_group_association" "private" {
  subnet_id                 = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.this["private"].id

  depends_on = [azurerm_network_security_rule.deny_internet_inbound]
}

# Optional NAT gateway: the private subnet reaches the internet, nothing reaches it.
resource "azurerm_public_ip" "nat" {
  count = var.advanced_settings.enable_nat_gateway ? 1 : 0

  name                = "${var.name_prefix}-nat-ip"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_nat_gateway" "this" {
  count = var.advanced_settings.enable_nat_gateway ? 1 : 0

  name                = "${var.name_prefix}-nat"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = "Standard"
  tags                = local.tags
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  count = var.advanced_settings.enable_nat_gateway ? 1 : 0

  nat_gateway_id       = azurerm_nat_gateway.this[0].id
  public_ip_address_id = azurerm_public_ip.nat[0].id
}

resource "azurerm_subnet_nat_gateway_association" "private" {
  count = var.advanced_settings.enable_nat_gateway ? 1 : 0

  subnet_id      = azurerm_subnet.private.id
  nat_gateway_id = azurerm_nat_gateway.this[0].id
}
