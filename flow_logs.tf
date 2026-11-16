# Optional VNet flow logs. Azure creates one Network Watcher per region, this module only uses it.
data "azurerm_network_watcher" "this" {
  count = var.advanced_settings.enable_flow_logs ? 1 : 0

  name                = local.network_watcher_name
  resource_group_name = local.network_watcher_resource_group
}

resource "random_string" "suffix" {
  count = var.advanced_settings.enable_flow_logs ? 1 : 0

  length  = 6
  special = false
  upper   = false
}

#trivy:ignore:AVD-AZU-0057 Access logging of the flow log account is out of scope for the demo
#trivy:ignore:AVD-AZU-0061 Infrastructure (double) encryption is out of scope for the demo, data is encrypted with Microsoft-managed keys
resource "azurerm_storage_account" "flow_logs" {
  #checkov:skip=CKV_AZURE_33:Queue service is not used
  #checkov:skip=CKV_AZURE_59:The firewall denies all traffic except trusted Azure services, which Network Watcher needs to write the logs
  #checkov:skip=CKV2_AZURE_1:Encrypted with Microsoft-managed keys, customer-managed keys are out of scope for the demo
  #checkov:skip=CKV2_AZURE_33:Network Watcher writes through the trusted services bypass of the firewall, a private endpoint is out of scope for the demo
  #checkov:skip=CKV2_AZURE_41:SAS tokens are not used
  #checkov:skip=CKV2_AZURE_40:Shared key access stays on. Microsoft does not document whether Network Watcher can write flow logs without it, and this was not tested
  count = var.advanced_settings.enable_flow_logs ? 1 : 0

  name                            = "${substr(replace(var.name_prefix, "-", ""), 0, 12)}flow${random_string.suffix[0].result}"
  location                        = azurerm_resource_group.this.location
  resource_group_name             = azurerm_resource_group.this.name
  account_tier                    = "Standard"
  account_replication_type        = "GRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  tags                            = local.tags

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  # Network Watcher writes to the account as a trusted Azure service.
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }
}

resource "azurerm_network_watcher_flow_log" "this" {
  #checkov:skip=CKV_AZURE_12:Retention is configurable via advanced_settings.flow_log_retention_days, the default is 90 days and 0 keeps the logs forever
  count = var.advanced_settings.enable_flow_logs ? 1 : 0

  name                 = "${var.name_prefix}-vnet-flow-log"
  network_watcher_name = data.azurerm_network_watcher.this[0].name
  resource_group_name  = data.azurerm_network_watcher.this[0].resource_group_name
  target_resource_id   = azurerm_virtual_network.this.id
  storage_account_id   = azurerm_storage_account.flow_logs[0].id
  enabled              = true
  version              = 2
  tags                 = local.tags

  retention_policy {
    enabled = var.advanced_settings.flow_log_retention_days > 0
    days    = var.advanced_settings.flow_log_retention_days
  }
}
