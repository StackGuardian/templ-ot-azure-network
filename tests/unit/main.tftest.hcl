# Unit tests: plan only, providers are mocked. No cloud account, no cost.
# Run: tofu test -test-directory=tests/unit
# Test case catalog: tests/README.md

# Some arguments are validated as Azure resource IDs, so mocked values must look real.
mock_provider "azurerm" {
  mock_data "azurerm_network_watcher" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/NetworkWatcherRG/providers/Microsoft.Network/networkWatchers/NetworkWatcher_germanywestcentral"
    }
  }

  mock_resource "azurerm_resource_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg"
    }
  }

  mock_resource "azurerm_virtual_network" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet"
    }
  }

  mock_resource "azurerm_subnet" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/mock-subnet"
    }
  }

  mock_resource "azurerm_network_security_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/networkSecurityGroups/mock-nsg"
    }
  }

  mock_resource "azurerm_public_ip" {
    defaults = {
      id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/publicIPAddresses/mock-ip"
      ip_address = "203.0.113.10"
    }
  }

  mock_resource "azurerm_nat_gateway" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/natGateways/mock-nat"
    }
  }

  mock_resource "azurerm_storage_account" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Storage/storageAccounts/mockflow"
    }
  }
}

# U-01
run "defaults_are_valid" {
  command = plan

  assert {
    condition     = (local.tags["Environment"] == "demo" && local.tags["ManagedBy"] == "opentofu" && local.tags["Project"] == var.name_prefix && local.tags["Repository"] != "")
    error_message = "Default tags are missing or wrong."
  }
}

# U-02
run "invalid_name_prefix_is_rejected" {
  command = plan

  variables {
    name_prefix = "Not Valid"
  }

  expect_failures = [var.name_prefix]
}

# U-03
run "custom_tags_are_merged" {
  command = plan

  variables {
    advanced_settings = {
      tags = { Owner = "tester" }
    }
  }

  assert {
    condition     = local.tags["Owner"] == "tester" && local.tags["ManagedBy"] == "opentofu"
    error_message = "Custom tags were not merged with the defaults."
  }
}

# U-04
run "default_layout_is_a_public_and_a_private_subnet" {
  command = plan

  assert {
    condition     = azurerm_subnet.public.name == "public" && azurerm_subnet.private.name == "private"
    error_message = "The subnets must be named public and private."
  }

  assert {
    condition     = one(azurerm_subnet.public.address_prefixes) == "10.0.0.0/24" && one(azurerm_subnet.private.address_prefixes) == "10.0.1.0/24"
    error_message = "Subnets must be 10.0.0.0/24 and 10.0.1.0/24."
  }

  assert {
    condition     = one(azurerm_virtual_network.this.address_space) == "10.0.0.0/16"
    error_message = "Default address space must be 10.0.0.0/16."
  }

  assert {
    condition     = azurerm_resource_group.this.location == var.location
    error_message = "The resource group must use the location variable."
  }
}

# U-05
run "private_subnet_has_no_default_outbound_access" {
  command = plan

  assert {
    condition     = azurerm_subnet.private.default_outbound_access_enabled == false
    error_message = "The private subnet must not have default outbound access."
  }
}

# U-06
run "each_subnet_has_an_nsg_denying_internet_inbound" {
  command = plan

  assert {
    condition     = azurerm_network_security_group.this["public"].name == "demo-public-nsg" && azurerm_network_security_group.this["private"].name == "demo-private-nsg"
    error_message = "Each subnet needs its own network security group."
  }

  assert {
    condition     = alltrue([for r in azurerm_network_security_rule.deny_internet_inbound : r.direction == "Inbound" && r.access == "Deny" && r.source_address_prefix == "Internet" && r.protocol == "*" && r.priority == 4000])
    error_message = "Both NSGs need a deny rule for inbound traffic from the internet."
  }

  assert {
    condition     = length(azurerm_network_security_rule.deny_internet_inbound) == 2
    error_message = "Expected one deny rule per NSG."
  }
}

# U-07
run "public_cidr_is_rejected" {
  command = plan

  variables {
    advanced_settings = {
      vnet_cidr = "8.8.0.0/16"
    }
  }

  expect_failures = [var.advanced_settings]
}

# U-08
run "vnet_cidr_prefix_out_of_range_is_rejected" {
  command = plan

  variables {
    advanced_settings = {
      vnet_cidr = "10.0.0.0/8"
    }
  }

  expect_failures = [var.advanced_settings]
}

# U-09
run "vnet_cidr_slash_25_is_rejected" {
  command = plan

  variables {
    advanced_settings = {
      vnet_cidr = "10.0.0.0/25"
    }
  }

  expect_failures = [var.advanced_settings]
}

# U-10
run "vnet_cidr_host_bits_are_rejected" {
  command = plan

  variables {
    advanced_settings = {
      vnet_cidr = "10.0.1.0/16"
    }
  }

  expect_failures = [var.advanced_settings]
}

# U-11
run "invalid_vnet_cidr_string_is_rejected" {
  command = plan

  variables {
    advanced_settings = {
      vnet_cidr = "not-a-cidr"
    }
  }

  expect_failures = [var.advanced_settings]
}

# U-12
run "other_private_ranges_are_accepted" {
  command = plan

  variables {
    advanced_settings = {
      vnet_cidr      = "192.168.0.0/24"
      subnet_newbits = 2
    }
  }

  assert {
    condition     = one(azurerm_subnet.public.address_prefixes) == "192.168.0.0/26" && one(azurerm_subnet.private.address_prefixes) == "192.168.0.64/26"
    error_message = "A /24 VNet with subnet_newbits = 2 must split into /26 subnets."
  }
}

# U-13
run "subnet_smaller_than_slash_29_is_rejected" {
  command = plan

  variables {
    advanced_settings = {
      vnet_cidr      = "10.0.0.0/24"
      subnet_newbits = 6
    }
  }

  expect_failures = [var.advanced_settings]
}

# U-14
run "subnet_newbits_out_of_range_is_rejected" {
  command = plan

  variables {
    advanced_settings = {
      subnet_newbits = 0
    }
  }

  expect_failures = [var.advanced_settings]
}

# U-15
run "nat_gateway_is_off_by_default" {
  command = plan

  assert {
    condition     = length(azurerm_nat_gateway.this) == 0 && length(azurerm_public_ip.nat) == 0 && length(azurerm_subnet_nat_gateway_association.private) == 0
    error_message = "No NAT resources may exist by default."
  }
}

# U-16
run "nat_gateway_serves_the_private_subnet" {
  command = plan

  variables {
    advanced_settings = {
      enable_nat_gateway = true
    }
  }

  assert {
    condition     = azurerm_nat_gateway.this[0].sku_name == "Standard" && azurerm_public_ip.nat[0].sku == "Standard" && azurerm_public_ip.nat[0].allocation_method == "Static"
    error_message = "The NAT gateway and its public IP must be Standard SKU, the IP static."
  }

  assert {
    condition     = length(azurerm_nat_gateway_public_ip_association.this) == 1 && length(azurerm_subnet_nat_gateway_association.private) == 1
    error_message = "The public IP and the private subnet must be associated with the NAT gateway."
  }
}

# U-17
run "flow_logs_are_off_by_default" {
  command = plan

  assert {
    condition     = length(azurerm_network_watcher_flow_log.this) == 0 && length(azurerm_storage_account.flow_logs) == 0 && length(data.azurerm_network_watcher.this) == 0
    error_message = "No flow log resources may exist by default."
  }
}

# U-18
run "flow_logs_use_the_existing_network_watcher" {
  command = plan

  variables {
    advanced_settings = {
      enable_flow_logs = true
    }
  }

  assert {
    condition     = data.azurerm_network_watcher.this[0].name == "NetworkWatcher_germanywestcentral" && data.azurerm_network_watcher.this[0].resource_group_name == "NetworkWatcherRG"
    error_message = "The default Network Watcher name and resource group are wrong."
  }

  assert {
    condition     = azurerm_network_watcher_flow_log.this[0].version == 2 && azurerm_network_watcher_flow_log.this[0].enabled && azurerm_network_watcher_flow_log.this[0].retention_policy[0].days == 90 && azurerm_network_watcher_flow_log.this[0].retention_policy[0].enabled
    error_message = "Flow log must be enabled, version 2, with 90 days retention."
  }
}

# U-19
run "flow_log_storage_account_is_locked_down" {
  command = plan

  variables {
    advanced_settings = {
      enable_flow_logs = true
    }
  }

  assert {
    condition     = azurerm_storage_account.flow_logs[0].min_tls_version == "TLS1_2" && azurerm_storage_account.flow_logs[0].https_traffic_only_enabled && azurerm_storage_account.flow_logs[0].allow_nested_items_to_be_public == false
    error_message = "The storage account must enforce TLS 1.2 and HTTPS and forbid public blobs."
  }

  assert {
    condition     = one(azurerm_storage_account.flow_logs[0].network_rules).default_action == "Deny" && contains(one(azurerm_storage_account.flow_logs[0].network_rules).bypass, "AzureServices")
    error_message = "The storage account firewall must deny by default and allow trusted Azure services."
  }
}

# U-20
run "flow_log_retention_zero_keeps_logs_forever" {
  command = plan

  variables {
    advanced_settings = {
      enable_flow_logs        = true
      flow_log_retention_days = 0
    }
  }

  assert {
    condition     = azurerm_network_watcher_flow_log.this[0].retention_policy[0].enabled == false
    error_message = "Retention 0 must turn the retention policy off."
  }
}

# U-21
run "custom_network_watcher_is_used" {
  command = plan

  variables {
    advanced_settings = {
      enable_flow_logs               = true
      network_watcher_name           = "my-watcher"
      network_watcher_resource_group = "my-watcher-rg"
    }
  }

  assert {
    condition     = data.azurerm_network_watcher.this[0].name == "my-watcher" && data.azurerm_network_watcher.this[0].resource_group_name == "my-watcher-rg"
    error_message = "The custom Network Watcher was not used."
  }
}

# U-22
run "invalid_flow_log_retention_is_rejected" {
  command = plan

  variables {
    advanced_settings = {
      flow_log_retention_days = 400
    }
  }

  expect_failures = [var.advanced_settings]
}

# U-23
run "outputs_match_the_network" {
  command = apply

  assert {
    condition     = output.vnet_cidr == "10.0.0.0/16" && output.public_subnet_cidr == "10.0.0.0/24" && output.private_subnet_cidr == "10.0.1.0/24"
    error_message = "CIDR outputs are wrong."
  }

  assert {
    condition     = output.resource_group_name == "demo-network-rg" && output.public_subnet_id != "" && output.private_subnet_id != "" && output.vnet_id != ""
    error_message = "Resource group, VNet or subnet outputs are missing."
  }

  assert {
    condition     = output.nat_gateway_id == null && output.nat_public_ip == null
    error_message = "NAT outputs must be null by default."
  }
}

# U-24
run "nat_outputs_are_set_when_nat_is_on" {
  command = apply

  variables {
    advanced_settings = {
      enable_nat_gateway = true
    }
  }

  assert {
    condition     = output.nat_gateway_id != null && output.nat_public_ip == "203.0.113.10"
    error_message = "NAT outputs are missing."
  }
}
