# Azure Network (VNet)

Creates a resource group with a virtual network, a public and a private subnet, and a network security group (NSG) for each subnet. A NAT gateway and VNet flow logs are optional and off by default.

It creates only the network: no servers and no databases. Use it as the base for workloads you deploy afterwards.

## What gets created

- A resource group and a virtual network
- A `public` and a `private` subnet. Azure subnets have no type, the two differ by NSG rules and NAT gateway. The names match the AWS template
- An NSG per subnet that denies all inbound traffic from the internet
- Optional: a NAT gateway with a public IP for the private subnet
- Optional: VNet flow logs in a new storage account, using an existing Network Watcher

## Before you start

- A workflow with an Azure cloud connector for the target subscription
- For flow logs: the Network Watcher that Azure creates per region must exist (default name `NetworkWatcher_<location>` in the resource group `NetworkWatcherRG`)

## Form fields

| Field | What it does | Default |
|---|---|---|
| Name prefix | Prefix for all resource names. 2 to 16 lowercase letters, digits or hyphens, starting with a letter | `demo` |
| Location | Azure location | `germanywestcentral` |

**Advanced Settings** (tick "Show advanced settings" to change them):

| Field | What it does | Default |
|---|---|---|
| VNet CIDR | IP range of the network. Must be a private range (10.x, 172.16-31.x or 192.168.x) with a prefix between /16 and /24 | `10.0.0.0/16` |
| Subnet newbits | Bits added to the VNet prefix for each subnet. 8 gives /24 subnets in a /16. The public subnet comes first | 8 |
| Enable NAT gateway | Lets the private subnet reach the internet. Billed hourly while it exists | off |
| Enable flow logs | VNet flow logs to a new storage account. Needs the existing Network Watcher | off |
| Flow log retention days | How long flow logs are kept, 0 keeps them forever | `90` |
| Network Watcher name | Name of the existing Network Watcher. Leave empty for `NetworkWatcher_<location>` | empty |
| Network Watcher resource group | Resource group of the existing Network Watcher | `NetworkWatcherRG` |
| Tags | Extra tags added to all resources | none |

If the subnets do not fit into the VNet range (subnets smaller than /29), the run stops with a message before anything is created.

## After the run

The workflow outputs show:

- `resource_group_name`, `vnet_id`, `vnet_name` and `vnet_cidr`: the network
- `public_subnet_id` and `private_subnet_id` (with `public_subnet_cidr` and `private_subnet_cidr`): deploy your workloads into these subnets
- `nat_gateway_id` and `nat_public_ip`: set only when the NAT gateway is on. The public IP is the address that outbound traffic from the private subnet comes from

## Security defaults

- The NSGs deny inbound traffic from the internet on both subnets. Add allow rules with a lower priority number than 4000 if a workload needs them
- The private subnet has no default outbound access. It reaches the internet only through the NAT gateway, if it is on
- The flow log storage account enforces TLS 1.2 and HTTPS and has no public access

## Cost and cleanup

The resource group, VNet, subnets and NSGs are free. The NAT gateway and its public IP are billed per hour while they exist, plus data processing, also when idle. Flow logs are billed for storage and flow log data. Destroy the resources from the workflow when the demo is over.

## Limits

- No peering, VPN, hub-spoke or DNS setup
- No Network Watcher is created, an existing one is used
- No third (data) subnet tier
