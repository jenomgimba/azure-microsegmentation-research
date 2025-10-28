# Azure Micro-Segmentation Research

## About

This repository contains the infrastructure and testing code for my MSc Cybersecurity research project evaluating the effectiveness of Azure micro-segmentation strategies against lateral movement attacks.

**Author:** Jenom John Gimba
**Institution:** National College of Ireland
**Programme:** MSc in Cybersecurity
**Research Focus:** Lateral movement containment using Azure micro-segmentation
**Objective:** Provide evidence-based security implementation guidance for cloud environments

## Project Overview

This research compares 4 different Azure network segmentation approaches to determine their effectiveness at preventing lateral movement attacks while measuring performance trade-offs.

### Configurations Tested

1. **Baseline** - Traditional perimeter security with flat network (control group)
2. **Config 1 (NSG)** - Subnet-level segmentation using Network Security Groups
3. **Config 2 (ASG)** - Workload-level segmentation using Application Security Groups
4. **Config 3 (Firewall)** - Enhanced defense-in-depth with NSG + ASG + Azure Firewall Premium

Each configuration deploys 3 VMs:
- `vm-web-1` - Web server (internet-facing, with public IP)
- `vm-app-1` - Application server (with public IP for testing)
- `vm-db-1` - Database server (private only)

### Attack Simulation

The research simulates MITRE ATT&CK lateral movement techniques from a compromised web server:
- **T1021.001** - Remote Desktop Protocol (RDP)
- **T1021.002** - SMB/Windows Admin Shares
- **PowerShell Remoting** - WinRM-based lateral movement

Attack flow: `Internet → vm-web-1 (compromised) → vm-app-1, vm-db-1 (targets)`

## Technology Stack

### Infrastructure as Code
- **Terraform** v3.0+ - Azure resource provisioning
- **Azure CLI** - Authentication and resource management

### Cloud Platform
- **Azure** - Cloud infrastructure provider
- **Azure for Students** - Subscription (quota-limited environment)

### Virtual Machines
- **Windows Server 2022 Datacenter** - VM operating system
- **Standard_B2as_v2** - VM size (2 cores, 8GB RAM, cost-optimized)

### Networking
- **Azure Virtual Networks** - Network isolation
- **Network Security Groups (NSG)** - Subnet-level firewall rules
- **Application Security Groups (ASG)** - Workload-level security policies
- **Azure Firewall Premium** - Advanced threat protection (Config 3 only)

### Monitoring & Security
- **Azure Monitor** - Metrics and logging
- **Log Analytics Workspace** - Centralized log storage
- **Azure Monitor Agent** - VM-level telemetry collection

### Testing & Automation
- **PowerShell 5.1+** - Attack simulation and performance testing scripts
- **Bash** - Deployment automation scripts

## Requirements

### Azure Subscription
- **Azure for Students** or standard Azure subscription
- **Minimum quota requirements:**
  - Total Regional vCPUs: 6 cores (for 3 VMs × 2 cores)
  - Standard Bsv2 Family vCPUs: 6 cores
  - Public IP addresses: 3 per region (2 VMs + 1 firewall for Config 3)
- **Allowed regions:** uksouth, norwayeast, francecentral, switzerlandnorth, or germanywestcentral

### Local Development Environment
- **Operating System:** Windows 10/11
- **Git Bash:** For running deployment scripts ([Download with Git for Windows](https://git-scm.com/download/win))
- **Terraform:** v1.0 or higher ([Download](https://www.terraform.io/downloads))
- **Azure CLI:** Latest version ([Download](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli))

### Access & Permissions
- Subscription-level **Contributor** or **Owner** role
- Ability to register resource providers (or use `skip_provider_registration = true`)

### Budget Considerations
- **Cost per configuration:** ~$15-25/day (optimized for Azure for Students)
- **Recommended approach:** Deploy one config at a time, test, then destroy
- **Estimated testing time:** 3-5 days per configuration

## Repository Structure

```
azure-microsegmentation-research/
├── baseline/                          # Baseline perimeter security
│   ├── main.tf                        # Network, NSG, monitoring
│   └── vms.tf                         # 3 VMs (web, app, db)
├── config1-nsg/                       # NSG subnet segmentation
│   ├── main.tf                        # Network with NSG rules
│   └── vms.tf                         # 3 VMs with subnet isolation
├── config2-asg/                       # ASG workload segmentation
│   ├── main.tf                        # Network with ASG policies
│   └── vms.tf                         # 3 VMs with ASG assignments
├── config3-firewall/                  # Enhanced firewall segmentation
│   ├── main.tf                        # Network + NSG + ASG + Firewall
│   └── vms.tf                         # 3 VMs with firewall routing
├── scripts/                           # Testing automation
│   ├── Invoke-LateralMovementTest.ps1 # Attack simulation (run from vm-web-1)
│   ├── Measure-Performance.ps1        # Performance metrics collection
│   └── Collect-AllData.ps1            # Master orchestration script
├── deploy-baseline.sh                 # Deploy baseline config
├── deploy-config1.sh                  # Deploy config 1 (NSG)
├── deploy-config2.sh                  # Deploy config 2 (ASG)
├── deploy-config3.sh                  # Deploy config 3 (Firewall)
├── destroy-all.sh                     # Interactive cleanup script
├── .gitignore                         # Excludes state files, results
└── README.md                          # This file

Note: All scripts run in Git Bash on Windows
```

## Setup Instructions

### 1. Navigate to Project Directory

```bash
# Navigate to the project directory
cd azure-microsegmentation-research
```

### 2. Install Prerequisites

**Install Git Bash (if not already installed):**
1. Download Git for Windows: https://git-scm.com/download/win
2. Run the installer and accept defaults
3. Git Bash will be available in your Start Menu

**Install Terraform:**
1. Download Terraform for Windows: https://www.terraform.io/downloads
2. Extract the `terraform.exe` file
3. Add to your system PATH or place in `C:\Windows\System32`
4. Or use Chocolatey: `choco install terraform`

**Install Azure CLI:**
1. Download Azure CLI for Windows: https://aka.ms/installazurecliwindows
2. Run the MSI installer
3. Restart your terminal after installation

**Verify installations (in Git Bash or PowerShell):**
```bash
terraform --version  # Should show v1.0+
az --version         # Should show Azure CLI
```

### 3. Authenticate with Azure

**Open Git Bash and run:**

```bash
# Login to Azure (opens browser for authentication)
az login

# List your subscriptions
az account list --output table

# Set the correct subscription (copy the subscription ID from the list above)
az account set --subscription "YOUR_SUBSCRIPTION_ID_HERE"

# Verify current subscription
az account show --output table
```

### 4. Deploy Infrastructure

**In Git Bash, run one of the deployment scripts:**

```bash
# Deploy baseline (recommended to start)
./deploy-baseline.sh

# OR deploy config 1 (NSG)
./deploy-config1.sh

# OR deploy config 2 (ASG)
./deploy-config2.sh

# OR deploy config 3 (Firewall)
./deploy-config3.sh
```

**Alternative: Deploy manually using Terraform commands**

```bash
cd baseline
terraform init
terraform plan
terraform apply
```

**Important:** Deploy only ONE configuration at a time due to budget constraints. Deployment takes approximately 10-15 minutes per configuration.

### 5. Access Virtual Machines

After deployment, get public IP addresses from output (in Git Bash):

```bash
cd baseline
terraform output
```

**Connect via Windows Remote Desktop:**

1. Press `Win + R`, type `mstsc`, press Enter
2. Enter the connection details:
   - **Computer:** [Use web_public_ip or app_public_ip from terraform output]
   - **Username:** azureadmin
   - **Password:** P@ssw0rd123!ComplexP@ss
3. Click "Connect" and accept the certificate warning

**Important:** Change the default password after first login in production scenarios. For research purposes, these credentials allow consistent testing across configurations.

### 6. Configure VMs for Testing

On **each VM** (vm-web-1, vm-app-1, vm-db-1), enable PowerShell remoting:

```powershell
# Open PowerShell as Administrator
Enable-PSRemoting -Force
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
Restart-Service WinRM
```

### 7. Run Attack Simulations

**On vm-web-1** (the compromised web server), run:

```powershell
# Navigate to scripts directory (copy scripts to VM first)
cd C:\scripts

# Run attack simulation
.\Invoke-LateralMovementTest.ps1 -ConfigName "baseline"

# Run performance tests
.\Measure-Performance.ps1 -ConfigName "baseline"

# OR run complete data collection
.\Collect-AllData.ps1 -ConfigName "baseline"
```

Results are saved to:
- `C:\AttackResults\` - Attack simulation results (JSON)
- `C:\PerformanceResults\` - Performance metrics (JSON)
- `C:\ResearchData\` - Combined data collection (JSON)

### 8. Collect Azure Monitor Logs

After running tests, query Azure Monitor (5-10 minute delay for log ingestion):

```bash
# Get workspace ID
cd baseline
terraform output

# In Azure Portal:
# Navigate to Log Analytics Workspace > Logs
# Run the KQL query saved in ResearchData folder
```

### 9. Clean Up Resources

**Interactive cleanup (recommended) - run in Git Bash:**

```bash
./destroy-all.sh
```

This script:
- Shows which configurations are deployed
- Lets you select which to destroy
- Confirms before deletion
- Removes all resources including resource groups

**Manual cleanup (Git Bash or PowerShell):**

```bash
cd baseline
terraform destroy -auto-approve
```

**Critical:** Always destroy resources immediately after testing to avoid unnecessary costs. With your $86 budget, leaving VMs running overnight can consume $15-25.

## Configuration Details

### Baseline (Control Group)
- **Network:** Single flat network (10.0.0.0/16)
- **Subnets:** One subnet for all VMs (10.0.1.0/24)
- **Security:** Minimal NSG rules, allow all internal traffic
- **Purpose:** Establish baseline metrics with no segmentation
- **Expected result:** High lateral movement success rate

### Config 1: NSG Segmentation
- **Network:** Multiple subnets (10.1.0.0/16)
  - Web subnet: 10.1.1.0/24
  - App subnet: 10.1.2.0/24
  - Database subnet: 10.1.3.0/24
- **Security:** NSG rules enforcing tier-to-tier restrictions
- **Key feature:** Web tier cannot directly access database
- **Expected result:** Reduced lateral movement, subnet-level control

### Config 2: ASG Segmentation
- **Network:** Shared subnet (10.2.0.0/16)
- **Security:** ASG-based policies attached to NICs
  - ASG-Web, ASG-App, ASG-Database
- **Key feature:** Policies follow VMs regardless of subnet
- **Expected result:** Flexible workload-based security

### Config 3: Azure Firewall Enhanced
- **Network:** Hub-spoke architecture (10.3.0.0/16)
- **Security:** NSG + ASG + Azure Firewall Premium
  - Threat intelligence
  - Application-level filtering
  - Deep packet inspection
- **Key feature:** Defense-in-depth with multiple security layers
- **Expected result:** Highest security, potential performance impact

## Metrics Collected

### Security Metrics
- Lateral movement success rate (%)
- Number of successful RDP connections
- Number of successful SMB share accesses
- Number of blocked lateral movement attempts

### Performance Metrics
- Network latency (ICMP ping, 100 samples)
- TCP throughput (10MB file transfer)
- Authentication overhead (WinRM session establishment)
- Resource utilization (CPU, memory)

## Data Analysis

After collecting test results, generate charts and tables for dissertation:

### Setup
```bash
# Copy JSON files from VM to local project directory
# Create folders: ./AttackResults, ./PerformanceResults, ./ResearchData
# Copy all JSON result files into these folders

# Install Python dependencies
pip install -r requirements.txt
```

### Generate Charts
```bash
# Run analysis script
python analyze-results.py
```

Generates 7 publication-ready charts (300 DPI PNG) in `./analysis-output/`:
- Lateral movement success rates
- Attack method breakdown (RDP vs SMB)
- Network latency comparison
- Network throughput
- Resource utilization
- Attack success heatmap
- Summary table (also exports CSV)

Script searches for JSON files in project directory first (`./AttackResults`, `./PerformanceResults`, `./ResearchData`), then falls back to `C:\` paths if running on VM.

## Cost Breakdown

| Resource Type | Quantity | Daily Cost | Notes |
|--------------|----------|-----------|-------|
| VMs (Standard_B2as_v2) | 3 | $12-18 | 2 cores, 8GB RAM each |
| Public IPs (Standard) | 2-3 | $1-2 | Static IPs for web/app |
| Virtual Network | 1 | $0 | No charge |
| NSG | 3 | $0 | No charge |
| ASG | 3 | $0 | No charge |
| Log Analytics | 1 | $1-3 | Based on ingestion |
| Azure Firewall Premium | 1 | $0-50 | **Config 3 only** |
| **Total per config** | | **$15-25** | Baseline, Config 1-2 |
| **Total Config 3** | | **$65-75** | Includes Firewall Premium |

**Budget management tips:**
- Deploy one configuration at a time
- Destroy resources immediately after testing
- Avoid leaving VMs running overnight
- Use Azure Cost Management to track spending

## Troubleshooting

### Quota Exceeded Errors
```
Error: creating Windows Virtual Machine: compute.VirtualMachinesClient
Status Code: 409 - Quota exceeded
```
**Solution:** Use smaller VM sizes (B2as_v2) or request quota increase

### Terraform State Issues
```
Error: Resource Group still contains resources
```
**Solution:** Already configured with `prevent_deletion_if_contains_resources = false`

### Public IP Quota
```
Error: Public IP quota exceeded (limit: 3)
```
**Solution:** Database VM doesn't have public IP (private only)

### RDP Connection Fails
```
Error: Cannot connect to VM / Connection timeout
```
**Solutions:**
1. Verify NSG allows port 3389 (RDP)
2. Check public IP address in terraform output
3. Ensure VM is running in Azure Portal
4. Wait 2-3 minutes after deployment completes
5. Check Windows Firewall isn't blocking outbound RDP
6. Verify you're using the correct public IP (web_public_ip or app_public_ip)

### PowerShell Remoting Blocked
```
Error: WinRM cannot complete the operation
```
**Solution:** Run on each VM:
```powershell
Enable-PSRemoting -Force
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
```

## Research Methodology

1. **Deploy infrastructure** - Deploy one configuration at a time
2. **Configure VMs** - Enable PowerShell remoting, install monitoring
3. **Run baseline tests** - Measure normal performance metrics
4. **Execute attacks** - Simulate lateral movement from vm-web-1
5. **Collect data** - Gather security and performance metrics
6. **Analyze results** - Statistical comparison (ANOVA, t-tests)
7. **Destroy resources** - Clean up to avoid costs
8. **Repeat** - Test next configuration

## Security Notes

- Default credentials are used for research consistency
- Infrastructure is ephemeral (create, test, destroy)
- Not intended for production use
- Attack simulations should only run in isolated research environments
- Ensure Azure for Students policies allow security testing

## License

This code is for academic research purposes.

## Author

**Jenom John Gimba**
MSc in Cybersecurity
National College of Ireland

This infrastructure code supports my dissertation research on evaluating micro-segmentation effectiveness against lateral movement attacks in Azure cloud environments.

## Support

For Azure-specific technical issues, refer to:
- [Azure Documentation](https://docs.microsoft.com/azure)
- [Terraform Azure Provider Docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
