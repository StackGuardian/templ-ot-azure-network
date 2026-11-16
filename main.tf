locals {
  tags = merge(
    {
      Project     = var.name_prefix
      Environment = "demo"
      ManagedBy   = "opentofu"
      Repository  = "tf-azure-network"
    },
    var.advanced_settings.tags,
  )

  # Public subnet first, private subnet second.
  public_cidr  = cidrsubnet(var.advanced_settings.vnet_cidr, var.advanced_settings.subnet_newbits, 0)
  private_cidr = cidrsubnet(var.advanced_settings.vnet_cidr, var.advanced_settings.subnet_newbits, 1)

  # Defaults of the Network Watcher that Azure creates per region.
  network_watcher_name           = coalesce(var.advanced_settings.network_watcher_name, "NetworkWatcher_${var.location}")
  network_watcher_resource_group = var.advanced_settings.network_watcher_resource_group
}

resource "azurerm_resource_group" "this" {
  name     = "${var.name_prefix}-network-rg"
  location = var.location
  tags     = local.tags
}
