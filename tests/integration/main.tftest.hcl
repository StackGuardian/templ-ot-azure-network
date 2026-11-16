# Integration tests: deploy real resources, check them, then destroy them.
# This costs almost nothing (the NAT gateway and flow logs stay off) and needs cloud credentials.
# Run: tofu test -test-directory=tests/integration
# Test case catalog: tests/README.md

variables {
  name_prefix = "itest"
  advanced_settings = {
    tags = {
      Purpose = "integration-test"
    }
  }
}

# I-01, I-02
run "deploy" {
  command = apply

  assert {
    condition     = output.vnet_cidr == "10.0.0.0/16" && output.public_subnet_cidr == "10.0.0.0/24" && output.private_subnet_cidr == "10.0.1.0/24"
    error_message = "The VNet or subnets have the wrong address ranges."
  }

  assert {
    condition     = azurerm_subnet.private.default_outbound_access_enabled == false && length(azurerm_network_security_group.this) == 2
    error_message = "The private subnet must have no default outbound access, and each subnet needs an NSG."
  }
}
