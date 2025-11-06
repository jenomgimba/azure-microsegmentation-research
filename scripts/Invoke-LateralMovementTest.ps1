# Attack Simulation Script - Tests lateral movement techniques

param(
    [Parameter(Mandatory=$true)]
    [string]$ConfigName,  # baseline, config1, config2, config3

    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "C:\AttackResults",

    [Parameter(Mandatory=$false)]
    [ValidateSet("vm-web-1", "vm-app-1", "vm-db-1")]
    [string]$SourceVM = "vm-web-1"
)

# Create output directory
New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$sourceLabel = $SourceVM.Replace("vm-", "").Replace("-1", "")
$resultsFile = Join-Path $OutputPath "attack-results-$ConfigName-from-$sourceLabel-$timestamp.json"

Write-Host "========================================"
Write-Host "Lateral Movement Attack Simulation"
Write-Host "Configuration: $ConfigName"
Write-Host "Source (compromised): $SourceVM"
Write-Host "Timestamp: $timestamp"
Write-Host "========================================"
Write-Host ""

# Determine target VMs based on source
$allVMs = @("vm-web-1", "vm-app-1", "vm-db-1")
$targetVMs = $allVMs | Where-Object { $_ -ne $SourceVM }

Write-Host "Targets: $($targetVMs -join ', ')" -ForegroundColor Gray
Write-Host ""

# Initialize results object
$results = @{
    Configuration = $ConfigName
    Timestamp = $timestamp
    SourceVM = $SourceVM
    TargetVMs = $targetVMs
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

$targets = $targetVMs | ForEach-Object {
    @{
        Name = $_
        Ports = @(3389, 80, 443, 445, 1433, 5985)
    }
}

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

# Check if AD module is already available (don't attempt installation to avoid hangs)
$adModuleAvailable = Get-Module -ListAvailable -Name ActiveDirectory

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
            # Module available but not domain-joined - simulate
            $reconResults.ADEnumeration = @{
                Method = "Simulated"
                DomainName = "workgroup.local"
                UserCount = 15
                ComputerCount = 3
                Success = $true
                Note = "Simulated - not domain-joined"
            }
            Write-Host "    Domain: workgroup.local (simulated)" -ForegroundColor Gray
            Write-Host "    Users: 15 (simulated)" -ForegroundColor Gray
            Write-Host "    Computers: 3 (simulated)" -ForegroundColor Gray
        }
    } catch {
        # AD module failed - simulate
        $reconResults.ADEnumeration = @{
            Method = "Simulated"
            DomainName = "workgroup.local"
            UserCount = 15
            ComputerCount = 3
            Success = $true
            Note = "Simulated - AD cmdlets failed"
        }
        Write-Host "    Domain: workgroup.local (simulated)" -ForegroundColor Gray
        Write-Host "    Users: 15 (simulated)" -ForegroundColor Gray
    }
} else {
    # No AD module - simulate (skip installation to avoid hangs)
    $reconResults.ADEnumeration = @{
        Method = "Simulated"
        DomainName = "workgroup.local"
        UserCount = 15
        ComputerCount = 3
        Success = $true
        Note = "Simulated - AD module not available"
    }
    Write-Host "    Domain: workgroup.local (simulated)" -ForegroundColor Gray
    Write-Host "    Users: 15 (simulated)" -ForegroundColor Gray
    Write-Host "    Computers: 3 (simulated)" -ForegroundColor Gray
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
    WMIAttempts = @()
    ScheduledTaskAttempts = @()
    ServiceAttempts = @()
}

# RDP Lateral Movement (T1021.001)
Write-Host "  [2.1] RDP lateral movement attempts..." -ForegroundColor Yellow

$rdpTargets = $targetVMs

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

$smbTargets = $targetVMs

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

Write-Host ""

# WMI Lateral Movement
Write-Host "  [2.4] WMI lateral movement attempts..." -ForegroundColor Yellow

foreach ($target in $targetVMs) {
    Write-Host "    Attempting WMI to $target..." -ForegroundColor Gray

    $wmiResult = @{
        Target = $target
        Timestamp = Get-Date
        Method = "WMI"
        Success = $false
        ErrorMessage = $null
    }

    try {
        # Test WMI access by attempting remote process creation
        $wmiTest = Invoke-WmiMethod -Class Win32_Process -Name Create `
            -ArgumentList "cmd.exe /c echo test" `
            -ComputerName $target -ErrorAction Stop

        if ($wmiTest.ReturnValue -eq 0) {
            $wmiResult.Success = $true
            Write-Host "      WMI execution successful - LATERAL MOVEMENT POSSIBLE" -ForegroundColor Red
        } else {
            Write-Host "      WMI execution failed - MOVEMENT PREVENTED" -ForegroundColor Green
        }
    } catch {
        $wmiResult.ErrorMessage = $_.Exception.Message
        Write-Host "      WMI blocked - MOVEMENT PREVENTED" -ForegroundColor Green
    }

    $lateralMoveResults.WMIAttempts += $wmiResult
    Start-Sleep -Milliseconds 500
}

Write-Host ""

# Scheduled Task Lateral Movement
Write-Host "  [2.5] Scheduled Task lateral movement attempts..." -ForegroundColor Yellow

foreach ($target in $targetVMs) {
    Write-Host "    Attempting Scheduled Task to $target..." -ForegroundColor Gray

    $taskResult = @{
        Target = $target
        Timestamp = Get-Date
        Method = "ScheduledTask"
        Success = $false
        ErrorMessage = $null
    }

    try {
        # Test scheduled task creation (schtasks command)
        $taskTest = schtasks /query /s $target /tn "TestTask" 2>&1

        if ($LASTEXITCODE -eq 0 -or $taskTest -notlike "*ERROR*") {
            $taskResult.Success = $true
            Write-Host "      Scheduled Task accessible - LATERAL MOVEMENT POSSIBLE" -ForegroundColor Red
        } else {
            Write-Host "      Scheduled Task blocked - MOVEMENT PREVENTED" -ForegroundColor Green
        }
    } catch {
        $taskResult.ErrorMessage = $_.Exception.Message
        Write-Host "      Scheduled Task blocked - MOVEMENT PREVENTED" -ForegroundColor Green
    }

    $lateralMoveResults.ScheduledTaskAttempts += $taskResult
    Start-Sleep -Milliseconds 500
}

Write-Host ""

# Service-based Lateral Movement
Write-Host "  [2.6] Service lateral movement attempts..." -ForegroundColor Yellow

foreach ($target in $targetVMs) {
    Write-Host "    Attempting Service creation on $target..." -ForegroundColor Gray

    $serviceResult = @{
        Target = $target
        Timestamp = Get-Date
        Method = "Service"
        Success = $false
        ErrorMessage = $null
    }

    try {
        # Test service management access (sc command)
        $serviceTest = sc.exe \\$target query 2>&1

        if ($LASTEXITCODE -eq 0 -and $serviceTest -notlike "*Access is denied*") {
            $serviceResult.Success = $true
            Write-Host "      Service management accessible - LATERAL MOVEMENT POSSIBLE" -ForegroundColor Red
        } else {
            Write-Host "      Service management blocked - MOVEMENT PREVENTED" -ForegroundColor Green
        }
    } catch {
        $serviceResult.ErrorMessage = $_.Exception.Message
        Write-Host "      Service management blocked - MOVEMENT PREVENTED" -ForegroundColor Green
    }

    $lateralMoveResults.ServiceAttempts += $serviceResult
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

# Calculate metrics (force array conversion with @() to ensure proper .Count)
$totalRDPAttempts = $lateralMoveResults.RDPAttempts.Count
$successfulRDP = @($lateralMoveResults.RDPAttempts | Where-Object { $_.Success -eq $true }).Count
$rdpSuccessRate = if ($totalRDPAttempts -gt 0) { ($successfulRDP / $totalRDPAttempts) * 100 } else { 0 }

$totalSMBAttempts = $lateralMoveResults.SMBAttempts.Count
$successfulSMB = @($lateralMoveResults.SMBAttempts | Where-Object { $_.Success -eq $true }).Count
$smbSuccessRate = if ($totalSMBAttempts -gt 0) { ($successfulSMB / $totalSMBAttempts) * 100 } else { 0 }

$totalPSAttempts = $lateralMoveResults.PSRemotingAttempts.Count
$successfulPS = @($lateralMoveResults.PSRemotingAttempts | Where-Object { $_.Success -eq $true }).Count
$psSuccessRate = if ($totalPSAttempts -gt 0) { ($successfulPS / $totalPSAttempts) * 100 } else { 0 }

$totalWMIAttempts = $lateralMoveResults.WMIAttempts.Count
$successfulWMI = @($lateralMoveResults.WMIAttempts | Where-Object { $_.Success -eq $true }).Count
$wmiSuccessRate = if ($totalWMIAttempts -gt 0) { ($successfulWMI / $totalWMIAttempts) * 100 } else { 0 }

$totalTaskAttempts = $lateralMoveResults.ScheduledTaskAttempts.Count
$successfulTask = @($lateralMoveResults.ScheduledTaskAttempts | Where-Object { $_.Success -eq $true }).Count
$taskSuccessRate = if ($totalTaskAttempts -gt 0) { ($successfulTask / $totalTaskAttempts) * 100 } else { 0 }

$totalServiceAttempts = $lateralMoveResults.ServiceAttempts.Count
$successfulService = @($lateralMoveResults.ServiceAttempts | Where-Object { $_.Success -eq $true }).Count
$serviceSuccessRate = if ($totalServiceAttempts -gt 0) { ($successfulService / $totalServiceAttempts) * 100 } else { 0 }

$totalAttempts = $totalRDPAttempts + $totalSMBAttempts + $totalPSAttempts + $totalWMIAttempts + $totalTaskAttempts + $totalServiceAttempts
$totalSuccessful = $successfulRDP + $successfulSMB + $successfulPS + $successfulWMI + $successfulTask + $successfulService
$overallSuccessRate = if ($totalAttempts -gt 0) { ($totalSuccessful / $totalAttempts) * 100 } else { 0 }

$results.Metrics = @{
    TotalLateralMovementAttempts = $totalAttempts
    SuccessfulLateralMovements = $totalSuccessful
    LateralMovementSuccessRate = [math]::Round($overallSuccessRate, 2)
    RDPSuccessRate = [math]::Round($rdpSuccessRate, 2)
    SMBSuccessRate = [math]::Round($smbSuccessRate, 2)
    PSRemotingSuccessRate = [math]::Round($psSuccessRate, 2)
    WMISuccessRate = [math]::Round($wmiSuccessRate, 2)
    ScheduledTaskSuccessRate = [math]::Round($taskSuccessRate, 2)
    ServiceSuccessRate = [math]::Round($serviceSuccessRate, 2)
    ByTechnique = @{
        RDP = "$successfulRDP / $totalRDPAttempts"
        SMB = "$successfulSMB / $totalSMBAttempts"
        PSRemoting = "$successfulPS / $totalPSAttempts"
        WMI = "$successfulWMI / $totalWMIAttempts"
        ScheduledTask = "$successfulTask / $totalTaskAttempts"
        Service = "$successfulService / $totalServiceAttempts"
    }
}

Write-Host "Metrics:"
Write-Host "  Total lateral movement attempts: $totalAttempts" -ForegroundColor White
Write-Host "  Successful movements: $totalSuccessful" -ForegroundColor $(if ($totalSuccessful -gt 0) { "Red" } else { "Green" })
Write-Host "  Overall success rate: $([math]::Round($overallSuccessRate, 2))%" -ForegroundColor $(if ($overallSuccessRate -gt 0) { "Red" } else { "Green" })
Write-Host ""
Write-Host "  By Technique:"
Write-Host "    RDP: $successfulRDP / $totalRDPAttempts ($([math]::Round($rdpSuccessRate, 2))%)" -ForegroundColor $(if ($rdpSuccessRate -gt 0) { "Red" } else { "Green" })
Write-Host "    SMB: $successfulSMB / $totalSMBAttempts ($([math]::Round($smbSuccessRate, 2))%)" -ForegroundColor $(if ($smbSuccessRate -gt 0) { "Red" } else { "Green" })
Write-Host "    PSRemoting: $successfulPS / $totalPSAttempts ($([math]::Round($psSuccessRate, 2))%)" -ForegroundColor $(if ($psSuccessRate -gt 0) { "Red" } else { "Green" })
Write-Host "    WMI: $successfulWMI / $totalWMIAttempts ($([math]::Round($wmiSuccessRate, 2))%)" -ForegroundColor $(if ($wmiSuccessRate -gt 0) { "Red" } else { "Green" })
Write-Host "    Scheduled Task: $successfulTask / $totalTaskAttempts ($([math]::Round($taskSuccessRate, 2))%)" -ForegroundColor $(if ($taskSuccessRate -gt 0) { "Red" } else { "Green" })
Write-Host "    Service: $successfulService / $totalServiceAttempts ($([math]::Round($serviceSuccessRate, 2))%)" -ForegroundColor $(if ($serviceSuccessRate -gt 0) { "Red" } else { "Green" })
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
