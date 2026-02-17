# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

All Terraform commands are run from the `terraform/` directory:

```bash
# Initialise providers and backend
terraform init

# Preview changes
terraform plan

# Apply changes
terraform apply

# Validate configuration syntax
terraform validate

# Format all .tf files
terraform fmt -recursive

# Target a specific resource
terraform plan -target=azurerm_mysql_flexible_server.snapvideo
terraform apply -target=azurerm_mysql_flexible_server.snapvideo

# Destroy all resources
terraform destroy
```

Workspaces are used to separate environments. The current workspace name is interpolated into resource names (e.g. `rg-snapvideo-dev-westeurope`):

```bash
terraform workspace list
terraform workspace select dev
terraform workspace new staging
```

## Architecture

This is a single-environment Azure PaaS deployment for "Snapvideo". All resources are provisioned into one resource group. The naming convention throughout is `<type>-<customer>-<workspace>-<location>`.

**Network topology** — one VNet (`10.0.0.0/16`) split across four subnets:

| Subnet | CIDR | Purpose |
|--------|------|---------|
| `subnet-aag` | `10.0.0.0/24` | Application Gateway (layer 7 ingress) |
| `subnet-web` | `10.0.1.0/24` | Windows VMSS (web tier) |
| `subnet-backend` | `10.0.2.0/24` | Linux VM availability set (API tier) |
| `subnet-database` | `10.0.3.0/24` | MySQL Flexible Server (delegated subnet) |

Traffic flows: Internet → App Gateway → VMSS (port 443) → backend LB at `10.0.2.240` (port 8080) → MySQL (port 3306, private DNS only).

**NSGs are attached to subnets**, not individual NICs. Each NSG allows only the expected inbound traffic for that tier; cross-tier flows are enforced by source/destination CIDR rules in `securitygroups.tf`.

**Secrets** — all passwords are generated with `random_password` (20 chars, special chars enabled), stored in Azure Key Vault (`keyvault.tf`), and referenced via `azurerm_key_vault_secret.<name>.value`. Nothing is hardcoded. The Key Vault access policy grants the deploying principal Get/List/Set on secrets.

**MySQL** uses a private endpoint via subnet delegation and a private DNS zone (`snapvideo.mysql.database.azure.com`) linked to the VNet. It is not reachable from the public internet.

**High availability:**
- App Gateway: `Standard_v2` with `capacity = 2`
- Web tier: VMSS (auto-scaling capable, currently `instances = 1`)
- Backend: `azurerm_availability_set` with 3 fault/update domains
- Database: `ZoneRedundant` HA with standby in zone 2

## File map

| File | Contents |
|------|----------|
| `main.tf` | Provider config, resource group, private DNS zone + VNet link |
| `network.tf` | VNet, subnets, backend internal LB, App Gateway, public IP |
| `securitygroups.tf` | NSGs (web, backend, database) + subnet associations |
| `compute.tf` | Windows VMSS (web), Linux VM + NIC + availability set (backend) |
| `database.tf` | MySQL Flexible Server |
| `keyvault.tf` | Key Vault, random passwords, Key Vault secrets |
| `variables.tf` | `location` and `customer` input variables |
| `dev.auto.tfvars` | Default values: `customer=snapvideo`, `location=westeurope` |

## Notes

- `dev.auto.tfvars` is gitignored (matches `*.tfvars`). It is committed in this repo intentionally; the values are non-sensitive customer/location strings.
- The lock file (`.terraform.lock.hcl`) is committed. Provider versions are pinned: `azurerm ~> 4.60.0`, `random 3.8.1`.
- The project was originally deployed via Terraform Cloud. There is no remote backend configured in the code; set one up before using in CI.
- `azurerm_public_ip.web` uses `allocation_method = "Dynamic"`, which is incompatible with App Gateway `Standard_v2` — this will error on `apply` and needs to be changed to `"Static"`.
- The `request_routing_rule` block in `network.tf` is missing a `priority` field, which is required by the `azurerm` v4 provider and will cause a plan error.
