variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "demo"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.name_prefix))
    error_message = "Use 2-16 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "location" {
  description = "Azure location"
  type        = string
  default     = "germanywestcentral"
}

# Grouped so the StackGuardian form can show them in one "Advanced Settings" section.
variable "advanced_settings" {
  description = "Settings most deployments keep at their defaults"
  type = object({
    vnet_cidr                      = optional(string, "10.0.0.0/16")      # Address space of the VNet, private range (RFC 1918), /16 to /24
    subnet_newbits                 = optional(number, 8)                  # Bits added to the VNet prefix for each subnet (8 gives /24 subnets in a /16)
    enable_nat_gateway             = optional(bool, false)                # NAT gateway for the private subnet. Billed hourly while it exists.
    enable_flow_logs               = optional(bool, false)                # VNet flow logs to a storage account. Needs an existing Network Watcher.
    flow_log_retention_days        = optional(number, 90)                 # Days to keep flow logs, 0 keeps them forever
    network_watcher_name           = optional(string)                     # Existing Network Watcher, default NetworkWatcher_<location>
    network_watcher_resource_group = optional(string, "NetworkWatcherRG") # Resource group of the existing Network Watcher
    tags                           = optional(map(string), {})            # Additional tags for all resources
  })
  default  = {}
  nullable = false

  validation {
    condition = try(
      cidrhost(var.advanced_settings.vnet_cidr, 0) == split("/", var.advanced_settings.vnet_cidr)[0] &&
      tonumber(split("/", var.advanced_settings.vnet_cidr)[1]) >= 16 &&
      tonumber(split("/", var.advanced_settings.vnet_cidr)[1]) <= 24 &&
      anytrue([for r in ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"] : cidrcontains(r, var.advanced_settings.vnet_cidr)]),
      false
    )
    error_message = "vnet_cidr must be a network address in a private range (10.0.0.0/8, 172.16.0.0/12 or 192.168.0.0/16) with a prefix between /16 and /24."
  }

  validation {
    condition     = var.advanced_settings.subnet_newbits >= 1 && var.advanced_settings.subnet_newbits <= 12 && var.advanced_settings.subnet_newbits == floor(var.advanced_settings.subnet_newbits)
    error_message = "subnet_newbits must be a whole number between 1 and 12."
  }

  # Two subnets must fit, and the smallest Azure subnet is /29.
  validation {
    condition = try(
      pow(2, var.advanced_settings.subnet_newbits) >= 2 &&
      tonumber(split("/", var.advanced_settings.vnet_cidr)[1]) + var.advanced_settings.subnet_newbits <= 29,
      false
    )
    error_message = "The subnets do not fit: the resulting subnet prefix must be /29 or larger."
  }

  validation {
    condition     = var.advanced_settings.flow_log_retention_days >= 0 && var.advanced_settings.flow_log_retention_days <= 365 && var.advanced_settings.flow_log_retention_days == floor(var.advanced_settings.flow_log_retention_days)
    error_message = "Flow log retention must be 0 (keep forever) or 1 to 365 days."
  }

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9_.-]{0,78}[A-Za-z0-9_]$", var.advanced_settings.network_watcher_resource_group))
    error_message = "network_watcher_resource_group is not a valid Azure resource group name."
  }
}
