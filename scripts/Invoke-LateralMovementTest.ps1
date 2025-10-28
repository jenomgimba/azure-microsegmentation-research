# Attack Simulation Script for Lateral Movement Testing
# Part of my MSc research project evaluating Azure micro-segmentation
# Simulates MITRE ATT&CK lateral movement techniques
# Run this from the compromised web server (vm-web-1)

param(
    [Parameter(Mandatory=$true)]
    [string]$ConfigName,  # baseline, config1, config2, config3
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "C:\AttackResults"
)

# Create output directory
New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$resultsFile = Join-Path $OutputPath "attack-results-$ConfigName-$timestamp.json"

Write-Host "========================================"
Write-Host "Lateral Movement Attack Simulation"
Write-Host "Configuration: $ConfigName"
Write-Host "Timestamp: $timestamp"
Write-Host "========================================"
Write-Host ""

# Initialize results object
$results = @{
    Configuration = $ConfigName
    Timestamp = $timestamp
    AttackPhases = @{}
}

# ============================================
# Phase 1: Reconnaissance
# ============================================
Write-Host "[Phase 1] Starting Reconnaissance..." -ForegroundColor Cyan

$reconResults = @{
    NetworkScan = @()
    CredentialDump = @{}
    ADEnumeration = @{}
}

# Network scanning - Discover targets
Write-Host "  [1.1] Network scanning for targets..." -ForegroundColor Yellow

$targets = @(
    @{Name="vm-app-1"; Ports=@(3389,80,443,445)},
    @{Name="vm-db-1"; Ports=@(3389,1433,445)}
)

foreach ($target in $targets) {
    Write-Host "    Scanning $($target.Name)..." -ForegroundColor Gray
    
    $scanResult = @{
        TargetName = $target.Name
        PortsOpen = @()
        PortsClosed = @()
        ScanTime = Get-Date
    }
    
    foreach ($port in $target.Ports) {
        try {
            $result = Test-NetConnection -ComputerName $target.Name -Port $port -WarningAction SilentlyContinue -ErrorAction Stop
            
            if ($result.TcpTestSucceeded) {
                $scanResult.PortsOpen += $port
                Write-Host "      Port $port`: OPEN" -ForegroundColor Green
            } else {
                $scanResult.PortsClosed += $port
                Write-Host "      Port $port`: CLOSED" -ForegroundColor Red
            }
        } catch {
            $scanResult.PortsClosed += $port
            Write-Host "      Port $port`: BLOCKED" -ForegroundColor Red
        }
        
        Start-Sleep -Milliseconds 100
    }
    
    $reconResults.NetworkScan += $scanResult
}

Write-Host ""

# Credential dumping
Write-Host "  [1.2] Credential harvesting..." -ForegroundColor Yellow
$reconResults.CredentialDump = @{
    Method = "Simulated-Mimikatz"
    CredentialsFound = 5
    Hashes = @("NTLM:hash1", "NTLM:hash2", "Kerberos:ticket1")
}
Write-Host "    Found 5 cached credentials" -ForegroundColor Green
Write-Host ""

# AD enumeration
Write-Host "  [1.3] Active Directory enumeration..." -ForegroundColor Yellow

# Check if AD module is available
$adModuleAvailable = Get-Module -ListAvailable -Name ActiveDirectory

if (-not $adModuleAvailable) {
    Write-Host "    AD module not found. Attempting to install..." -ForegroundColor Yellow

    try {
        # Install RSAT AD PowerShell module
        Install-WindowsFeature -Name RSAT-AD-PowerShell -ErrorAction Stop | Out-Null
        Write-Host "    AD module installed successfully" -ForegroundColor Green

        # Refresh module availability
        $adModuleAvailable = Get-Module -ListAvailable -Name ActiveDirectory
    } catch {
        Write-Host "    Failed to install AD module: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

if ($adModuleAvailable) {
    try {
        Import-Module ActiveDirectory -ErrorAction Stop

        # Check if we're in a domain environment
        $computerSystem = Get-WmiObject -Class Win32_ComputerSystem

        if ($computerSystem.PartOfDomain) {
            # We're domain-joined, perform real AD enumeration
            $domain = Get-ADDomain -ErrorAction Stop
            $users = Get-ADUser -Filter * -ErrorAction Stop | Measure-Object
            $computers = Get-ADComputer -Filter * -ErrorAction Stop | Measure-Object

            $reconResults.ADEnumeration = @{
                DomainName = $domain.Name
                UserCount = $users.Count
                ComputerCount = $computers.Count
                Success = $true
            }

            Write-Host "    Domain: $($domain.Name)" -ForegroundColor Green
            Write-Host "    Users: $($users.Count)" -ForegroundColor Green
            Write-Host "    Computers: $($computers.Count)" -ForegroundColor Green
        } else {
            # Module installed but not domain-joined
            $reconResults.ADEnumeration = @{
                Method = "Simulated-NoAD"
                Success = $false
                Note = "AD module available but not domain-joined"
            }
            Write-Host "    AD module available but VM is not domain-joined" -ForegroundColor Gray
        }
    } catch {
        $reconResults.ADEnumeration = @{
            Success = $false
            Error = $_.Exception.Message
        }
        Write-Host "    AD enumeration failed: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    # Could not install AD module
    $reconResults.ADEnumeration = @{
        Method = "Simulated-NoAD"
        Success = $false
        Note = "Could not install AD module"
    }
    Write-Host "    Unable to install AD module - simulating standalone environment" -ForegroundColor Gray
}

$results.AttackPhases.Reconnaissance = $reconResults
Write-Host ""

# ============================================
# Phase 2: Lateral Movement
# ============================================
Write-Host "[Phase 2] Attempting Lateral Movement..." -ForegroundColor Cyan

$lateralMoveResults = @{
    RDPAttempts = @()
    SMBAttempts = @()
    PSRemotingAttempts = @()
}

# RDP Lateral Movement (T1021.001)
Write-Host "  [2.1] RDP lateral movement attempts..." -ForegroundColor Yellow

$rdpTargets = @("vm-app-1", "vm-db-1")

foreach ($target in $rdpTargets) {
    Write-Host "    Attempting RDP to $target..." -ForegroundColor Gray
    
    $rdpResult = @{
        Target = $target
        Timestamp = Get-Date
        Method = "RDP"
        Success = $false
        ErrorMessage = $null
    }
    
    try {
        # Test RDP port accessibility
        $rdpTest = Test-NetConnection -ComputerName $target -Port 3389 -WarningAction SilentlyContinue -ErrorAction Stop
        
        if ($rdpTest.TcpTestSucceeded) {
            $rdpResult.Success = $true
            $rdpResult.PortAccessible = $true
            Write-Host "      RDP port accessible - LATERAL MOVEMENT POSSIBLE" -ForegroundColor Red
        } else {
            $rdpResult.PortAccessible = $false
            Write-Host "      RDP port blocked - MOVEMENT PREVENTED" -ForegroundColor Green
        }
    } catch {
        $rdpResult.PortAccessible = $false
        $rdpResult.ErrorMessage = $_.Exception.Message
        Write-Host "      RDP blocked - MOVEMENT PREVENTED" -ForegroundColor Green
    }
    
    $lateralMoveResults.RDPAttempts += $rdpResult
    Start-Sleep -Milliseconds 500
}

Write-Host ""

# SMB Lateral Movement (T1021.002)
Write-Host "  [2.2] SMB lateral movement attempts..." -ForegroundColor Yellow

$smbTargets = @("vm-app-1", "vm-db-1")

foreach ($target in $smbTargets) {
    Write-Host "    Attempting SMB to $target..." -ForegroundColor Gray
    
    $smbResult = @{
        Target = $target
        Timestamp = Get-Date
        Method = "SMB"
        Success = $false
        ErrorMessage = $null
    }
    
    try {
        # Test SMB share access
        $share = "\\$target\C$"
        $testPath = Test-Path $share -ErrorAction Stop
        
        if ($testPath) {
            $smbResult.Success = $true
            $smbResult.ShareAccessible = $true
            Write-Host "      SMB share accessible - LATERAL MOVEMENT POSSIBLE" -ForegroundColor Red
        } else {
            $smbResult.ShareAccessible = $false
            Write-Host "      SMB access denied - MOVEMENT PREVENTED" -ForegroundColor Green
        }
    } catch {
        $smbResult.ShareAccessible = $false
        $smbResult.ErrorMessage = $_.Exception.Message
        Write-Host "      SMB blocked - MOVEMENT PREVENTED" -ForegroundColor Green
    }
    
    $lateralMoveResults.SMBAttempts += $smbResult
    Start-Sleep -Milliseconds 500
}

Write-Host ""

# PowerShell Remoting
Write-Host "  [2.3] PowerShell Remoting attempts..." -ForegroundColor Yellow

foreach ($target in $rdpTargets) {
    Write-Host "    Attempting PS Remoting to $target..." -ForegroundColor Gray
    
    $psResult = @{
        Target = $target
        Timestamp = Get-Date
        Method = "PSRemoting"
        Success = $false
        ErrorMessage = $null
    }
    
    try {
        $session = Test-WSMan -ComputerName $target -ErrorAction Stop
        
        if ($session) {
            $psResult.Success = $true
            Write-Host "      PS Remoting accessible - LATERAL MOVEMENT POSSIBLE" -ForegroundColor Red
        }
    } catch {
        $psResult.ErrorMessage = $_.Exception.Message
        Write-Host "      PS Remoting blocked - MOVEMENT PREVENTED" -ForegroundColor Green
    }
    
    $lateralMoveResults.PSRemotingAttempts += $psResult
    Start-Sleep -Milliseconds 500
}

$results.AttackPhases.LateralMovement = $lateralMoveResults
Write-Host ""

# ============================================
# Phase 3: Privilege Escalation
# ============================================
Write-Host "[Phase 3] Privilege Escalation Attempts..." -ForegroundColor Cyan

$privEscResults = @{
    DomainAdminAccess = @{}
    ServiceAccountAbuse = @{}
}

Write-Host "  [3.1] Checking domain admin access..." -ForegroundColor Yellow

$privEscResults.DomainAdminAccess = @{
    Success = $false
    Blocked = $true
    Note = "No DC in 3-VM setup"
}
Write-Host "    No domain controller present in this configuration" -ForegroundColor Gray

$results.AttackPhases.PrivilegeEscalation = $privEscResults
Write-Host ""

# ============================================
# Phase 4: Data Exfiltration Simulation
# ============================================
Write-Host "[Phase 4] Data Exfiltration Simulation..." -ForegroundColor Cyan

$exfilResults = @{
    DatabaseAccess = @()
    FileAccess = @()
}

Write-Host "  [4.1] Attempting database server access..." -ForegroundColor Yellow

$dbTargets = @("vm-db-1")

foreach ($target in $dbTargets) {
    Write-Host "    Testing SQL port on $target..." -ForegroundColor Gray
    
    $dbResult = @{
        Target = $target
        Timestamp = Get-Date
        Success = $false
    }
    
    try {
        $sqlTest = Test-NetConnection -ComputerName $target -Port 1433 -WarningAction SilentlyContinue -ErrorAction Stop
        
        if ($sqlTest.TcpTestSucceeded) {
            $dbResult.Success = $true
            Write-Host "      SQL port accessible - EXFILTRATION POSSIBLE" -ForegroundColor Red
        } else {
            Write-Host "      SQL port blocked - EXFILTRATION PREVENTED" -ForegroundColor Green
        }
    } catch {
        Write-Host "      SQL access blocked - EXFILTRATION PREVENTED" -ForegroundColor Green
    }
    
    $exfilResults.DatabaseAccess += $dbResult
}

$results.AttackPhases.DataExfiltration = $exfilResults
Write-Host ""

# ============================================
# Summary and Metrics
# ============================================
Write-Host "[Summary] Attack Simulation Complete" -ForegroundColor Cyan
Write-Host ""

# Calculate metrics
$totalRDPAttempts = $lateralMoveResults.RDPAttempts.Count
$successfulRDP = ($lateralMoveResults.RDPAttempts | Where-Object { $_.Success }).Count
$rdpSuccessRate = if ($totalRDPAttempts -gt 0) { ($successfulRDP / $totalRDPAttempts) * 100 } else { 0 }

$totalSMBAttempts = $lateralMoveResults.SMBAttempts.Count
$successfulSMB = ($lateralMoveResults.SMBAttempts | Where-Object { $_.Success }).Count
$smbSuccessRate = if ($totalSMBAttempts -gt 0) { ($successfulSMB / $totalSMBAttempts) * 100 } else { 0 }

$totalAttempts = $totalRDPAttempts + $totalSMBAttempts
$totalSuccessful = $successfulRDP + $successfulSMB
$overallSuccessRate = if ($totalAttempts -gt 0) { ($totalSuccessful / $totalAttempts) * 100 } else { 0 }

$results.Metrics = @{
    TotalLateralMovementAttempts = $totalAttempts
    SuccessfulLateralMovements = $totalSuccessful
    LateralMovementSuccessRate = [math]::Round($overallSuccessRate, 2)
    RDPSuccessRate = [math]::Round($rdpSuccessRate, 2)
    SMBSuccessRate = [math]::Round($smbSuccessRate, 2)
}

Write-Host "Metrics:"
Write-Host "  Total lateral movement attempts: $totalAttempts" -ForegroundColor White
Write-Host "  Successful movements: $totalSuccessful" -ForegroundColor $(if ($totalSuccessful -gt 0) { "Red" } else { "Green" })
Write-Host "  Success rate: $($overallSuccessRate)%" -ForegroundColor $(if ($overallSuccessRate -gt 0) { "Red" } else { "Green" })
Write-Host "  RDP success rate: $($rdpSuccessRate)%" -ForegroundColor $(if ($rdpSuccessRate -gt 0) { "Red" } else { "Green" })
Write-Host "  SMB success rate: $($smbSuccessRate)%" -ForegroundColor $(if ($smbSuccessRate -gt 0) { "Red" } else { "Green" })
Write-Host ""

# Save results
$results | ConvertTo-Json -Depth 10 | Out-File -FilePath $resultsFile -Encoding UTF8

Write-Host "Results saved to: $resultsFile" -ForegroundColor Green
Write-Host ""
Write-Host "========================================"
Write-Host "Simulation Complete"
Write-Host "========================================"

# Return results object
return $results
