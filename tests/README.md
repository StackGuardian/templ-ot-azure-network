# Tests

Tests use the built-in OpenTofu test framework (`tofu test`, OpenTofu 1.9 or later).

| Level | Folder | What it does | Cost | When it runs |
|---|---|---|---|---|
| Unit | `tests/unit` | Plan only with mocked providers. Checks configuration and security settings. | None | Merge requests into `development` or `main`, and tags |
| Integration | `tests/integration` | Deploys real resources, checks them, destroys them. | Cloud cost while running | Tags, when cloud credentials are set (`integration-tests` job) |

In the GitLab pipeline, the `unit-tests` job also publishes the results as a JUnit test report (**Tests** tab of the pipeline and of the merge request). The script `ci/tofu-json-to-junit.py` converts the output of `tofu test -json` to JUnit XML.

## Run locally

```bash
tofu init
tofu test -test-directory=tests/unit
tofu test -test-directory=tests/integration   # needs cloud credentials
```

## Test cases

| ID | Level | Description | Status |
|---|---|---|---|
| U-01 | Unit | Default variables produce a valid plan with all default tags | done |
| U-02 | Unit | Invalid `name_prefix` is rejected | done |
| U-03 | Unit | Custom `advanced_settings.tags` are merged with the default tags | done |
| U-04 | Unit | Default layout: VNet `10.0.0.0/16` with a `public` and a `private` subnet (`/24`), public first | done |
| U-05 | Unit | The private subnet has no default outbound access | done |
| U-06 | Unit | Each subnet has its own NSG with a rule that denies all inbound traffic from the internet | done |
| U-07 | Unit | A public CIDR block (`8.8.0.0/16`) is rejected | done |
| U-08 | Unit | A VNet prefix broader than `/16` (`10.0.0.0/8`) is rejected | done |
| U-09 | Unit | A VNet prefix narrower than `/24` (`10.0.0.0/25`) is rejected | done |
| U-10 | Unit | A CIDR with host bits set (`10.0.1.0/16`) is rejected | done |
| U-11 | Unit | A string that is not a CIDR block is rejected | done |
| U-12 | Unit | `192.168.0.0/24` with `subnet_newbits = 2` is accepted and split into `/26` subnets | done |
| U-13 | Unit | A subnet prefix longer than `/29` (`/24` VNet with 6 bits) is rejected | done |
| U-14 | Unit | `subnet_newbits = 0` (no room for two subnets) is rejected | done |
| U-15 | Unit | NAT gateway is off by default: no NAT gateway, public IP or association | done |
| U-16 | Unit | `enable_nat_gateway = true` creates a Standard NAT gateway with a static Standard public IP, attached to the private subnet only | done |
| U-17 | Unit | Flow logs are off by default: no storage account, no flow log, no Network Watcher lookup | done |
| U-18 | Unit | `enable_flow_logs = true` creates a flow log for the VNet in the existing Network Watcher (default name `NetworkWatcher_<location>`) with 90 days retention | done |
| U-19 | Unit | The flow log storage account enforces TLS 1.2 and HTTPS, has no public blob access and denies network access except trusted Azure services | done |
| U-20 | Unit | `flow_log_retention_days = 0` disables the retention policy (logs are kept forever) | done |
| U-21 | Unit | A custom Network Watcher name and resource group are passed to the lookup | done |
| U-22 | Unit | A retention above 365 days is rejected | done |
| U-23 | Unit | Outputs list the resource group, VNet CIDR, subnet IDs and subnet CIDRs; NAT outputs are null when the NAT gateway is off | done |
| U-24 | Unit | With the NAT gateway on, the outputs give its ID and public IP | done |
| I-01 | Integration | Deploy succeeds with the default VNet and subnet address ranges | written, not run |
| I-02 | Integration | The private subnet has no default outbound access and each subnet has an NSG | written, not run |

Integration tests (I-xx) are written and validated (`tofu validate -test-directory=tests/integration`) but have not been run against a real cloud account yet.
