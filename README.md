# Azure Micro-Segmentation Research

MSc Cybersecurity Research by Jenom John Gimba, National College of Ireland

## What is This?

This project tests how well different Azure network security setups can stop attackers from moving between servers. We test 4 different configurations and measure which one stops attacks best while keeping good performance.

## The 4 Configurations

1. **Baseline** - No security (to see how bad it can get)
2. **Config1** - Network Security Groups (basic subnet protection)
3. **Config2** - Application Security Groups (workload-based protection)
4. **Config3** - Azure Firewall + NSG + ASG (maximum protection)

Each setup has 3 Windows servers: Web, App, and Database.

## What You Need

**Before starting:**
- Azure subscription (Azure for Students works)
- Windows computer
- About $15-25 per day for testing (destroy resources after to save money)

**Software to install:**
1. **Git Bash** - [Download here](https://git-scm.com/download/win) (choose default options)
2. **Terraform** - [Download here](https://www.terraform.io/downloads) (extract and add to PATH)
3. **Azure CLI** - [Download here](https://aka.ms/installazurecliwindows) (run installer)

**Check everything is installed:**
Open Git Bash and type:
```bash
terraform --version
az --version
```
Both should show version numbers.

## Quick Start Guide

### Step 1: Login to Azure

Open Git Bash and run:
```bash
az login
```
A browser will open - login with your Azure account.

Set your subscription:
```bash
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

### Step 2: Deploy Infrastructure

**Deploy one configuration at a time** (takes 10-15 minutes):

```bash
cd baseline
terraform init
terraform apply
```

Type `yes` when asked to confirm.

**Alternative:** Use the deploy scripts:
```bash
./deploy-baseline.sh
```

### Step 3: Connect to Servers

After deployment, get the server addresses:
```bash
terraform output
```

Connect using Windows Remote Desktop:
1. Press Windows key + R
2. Type `mstsc` and press Enter
3. Enter the IP address from terraform output
4. Username: `azureadmin`
5. Password: `P@ssw0rd123!ComplexP@ss`

### Step 4: Run Tests

Copy the scripts folder to each server at `C:\scripts`

On the web server, open PowerShell as Administrator and run:
```powershell
cd C:\scripts
.\Collect-AllData.ps1 -ConfigName "baseline" -Iterations 5
```

This will:
- Run 5 test iterations automatically
- Test attack simulations
- Measure performance
- Save results to C:\ResearchData

**Wait 15-20 minutes for tests to complete.**

### Step 5: Export Logs

Before destroying resources, save the Azure logs.

On your local computer (PowerShell):
```powershell
cd scripts
.\Export-AzureLogs.ps1 -ConfigName "baseline"
```

This saves all logs before they're deleted.

### Step 6: Destroy Resources

**Important:** Always destroy resources after testing to avoid costs.

```bash
cd baseline
terraform destroy
```

Type `yes` to confirm.

Or use the cleanup script:
```bash
./destroy-all.sh
```

### Step 7: Repeat for Other Configs

After baseline is done, repeat Steps 2-6 for:
- Config1 (deploy-config1.sh)
- Config2 (deploy-config2.sh)
- Config3 (deploy-config3.sh)

### Step 8: Analyze Results

After testing all 4 configurations, analyze the data:

```bash
python analyze-results.py
```

This creates charts and tables in the `analysis-output` folder showing:
- Which configuration blocks attacks best
- Performance impact of each security setup
- Statistical analysis

## Folder Structure

```
Project/
├── baseline/           - Config with no security
├── config1-nsg/        - Config with Network Security Groups
├── config2-asg/        - Config with Application Security Groups
├── config3-firewall/   - Config with Azure Firewall
├── scripts/            - Testing scripts
│   ├── Collect-AllData.ps1           - Main test script
│   ├── Invoke-LateralMovementTest.ps1 - Attack simulation
│   ├── Measure-Performance.ps1        - Performance tests
│   └── Export-AzureLogs.ps1          - Log export
├── deploy-baseline.sh  - Quick deploy script for baseline
├── deploy-config1.sh   - Quick deploy script for config1
├── deploy-config2.sh   - Quick deploy script for config2
├── deploy-config3.sh   - Quick deploy script for config3
├── destroy-all.sh      - Clean up all resources
└── analyze-results.py  - Generate charts and analysis
```

## Common Problems

**Can't connect to server:**
- Wait 2-3 minutes after deployment
- Check you're using the correct IP address
- Make sure firewall isn't blocking Remote Desktop

**Quota exceeded error:**
- You might not have enough Azure quota
- Try a different region: uksouth, norwayeast, or francecentral

**Scripts won't run:**
- Make sure you're using PowerShell as Administrator
- Check scripts are in C:\scripts on the server

**Out of money:**
- Always destroy resources after testing
- Only deploy one config at a time
- Config 3 is most expensive ($65/day) - test it last

## Important Notes

- **Cost:** Destroy resources immediately after testing
- **One at a time:** Only deploy one configuration at a time
- **Save logs:** Always run Export-AzureLogs.ps1 before destroying
- **5 iterations:** Run tests 5 times for reliable statistics
- **Order:** Test in order: baseline → config1 → config2 → config3

## Need Help?

- Azure Docs: https://docs.microsoft.com/azure
- Terraform Docs: https://www.terraform.io/docs
- Azure CLI Docs: https://docs.microsoft.com/en-us/cli/azure/

## Author

Jenom John Gimba
MSc in Cybersecurity
National College of Ireland
