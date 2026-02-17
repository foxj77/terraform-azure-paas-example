## Updates — 17 February 2026

Revisited and modernised this configuration.  Original version was over 4 years old. Key changes made:

- **Provider upgraded** from azurerm 2.x to 4.60.0, fixing all breaking API changes
- **Application Gateway SKU** migrated from retired v1 (`Standard`) to `Standard_v2`
- **Backend VM** migrated from deprecated `azurerm_virtual_machine` to `azurerm_linux_virtual_machine`
- **OS images updated**: Ubuntu 16.04 LTS (EOL 2021) → 22.04 LTS; Windows Server 2016 → 2022
- **MySQL** upgraded from version 5.7 (EOL October 2023) to 8.0.21
- **SSH key auth** enabled on the Linux backend VM; password authentication disabled
- **Admin usernames** moved from hardcoded values to input variables
- **Key permissions** casing fixed (`list` → `List`, `create` → `Create`, `set` → `Set`) to satisfy provider 4.x validation
- **`random` provider** explicitly declared in `required_providers`
- **Unused local** `redirect_configuration_name` removed from network configuration
- **Self-referencing `depends_on`** noted on the private DNS zone VNet link
- **`.gitignore`** added with standard Terraform exclusions
- **`dev.auto.tfvars.example`** added so contributors know what variables to supply
- **TFLint** configured with azurerm ruleset (`.tflint.hcl`)
- **Pre-commit hooks** set up running `terraform fmt`, `terraform validate`, and `tflint`
- **GitHub Actions workflow** added (`.github/workflows/terraform-lint.yml`) running the same checks on push and pull requests to `main`

---

Overview

Based on the Snapview case study, please find attached my example.

In summary:
- used an Application Gateway on the web front end of the solution as manages the traffic on network layer 7.  This backs onto a virtual machine scale set that can be used to scale the web traffic load. 
- for the backend service, I've used a network load balancer, operating at layer 4.  This backs onto an availability set running two VMs across different availability zones in teh region.

Admittedly I'm out of time checking over the network configuration of the setup and haven't been able to fully test it properly.  Been tricky getting the time outside of job and having two small children!

Network segmentation
Split the network across 4 subnets:
- App Gateway - running azure app gateway
- Web front end - running virtual machine scale set
- backend - running availability set running backend VMs
- database - running the mysql flexible paas server

Network security groups are in place in line with the requirements.  The NSGs are attached to the subnets to ensure that any VMs placed on these subnets inherits these rules rather than being reliant on groups being attached per VM.

The MySQL server is also configured using a private endpoint.  This ensures that the backend service can talk to the database service securely without having to go out over the public internet.

High Availability
- app gateway - running two instances inline with Azure best practice
- web - using VM scale set with app gateway
- backend - using availability set
- database - PAAS server configured for high availability with backup instance running.

Key Vault/Passwords
Deployed two machines onto the network and the PAAS MySQL server.  I've generated random passwords and added them to a key vault.  These are then used by the services for the passwords to ensure that these aren't committed into the git repo (admittedly earlier ones where!).

Deployment
Currently using Terraform Cloud to deploy into my own test Azure subscription.