# Performance Measurement Script
# Part of my MSc research project evaluating Azure micro-segmentation
# Tests latency, throughput, and authentication overhead across configurations

param(
    [Parameter(Mandatory=$true)]
    [string]$ConfigName,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "C:\PerformanceResults"
)

New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$resultsFile = Join-Path $OutputPath "performance-$ConfigName-$timestamp.json"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Performance Testing - $ConfigName"
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$results = @{
    Configuration = $ConfigName
    Timestamp = $timestamp
    Tests = @{}
}

# Target VMs for testing (3 VM setup: web, app, db)
$targets = @(
    @{Name="vm-app-1"; Type="Application"},
    @{Name="vm-db-1"; Type="Database"}
)

# ============================================
# Test 1: Network Latency (ICMP)
# ============================================
Write-Host "[Test 1] Network Latency Testing" -ForegroundColor Yellow

$latencyResults = @()

foreach ($target in $targets) {
    Write-Host "  Testing latency to $($target.Name)..." -ForegroundColor Gray
    
    $pingResults = Test-Connection -ComputerName $target.Name -Count 100 -ErrorAction SilentlyContinue
    
    if ($pingResults) {
        $latencies = $pingResults | ForEach-Object { $_.ResponseTime }
        
        $latencyData = @{
            Target = $target.Name
            TargetType = $target.Type
            SampleCount = $latencies.Count
            MinLatency = ($latencies | Measure-Object -Minimum).Minimum
            MaxLatency = ($latencies | Measure-Object -Maximum).Maximum
            AvgLatency = [math]::Round(($latencies | Measure-Object -Average).Average, 2)
            MedianLatency = ($latencies | Sort-Object)[[math]::Floor($latencies.Count / 2)]
            P95Latency = ($latencies | Sort-Object)[[math]::Floor($latencies.Count * 0.95)]
            P99Latency = ($latencies | Sort-Object)[[math]::Floor($latencies.Count * 0.99)]
        }
        
        Write-Host "    Avg: $($latencyData.AvgLatency)ms, P95: $($latencyData.P95Latency)ms" -ForegroundColor Green
        
        $latencyResults += $latencyData
    } else {
        Write-Host "    Connection failed" -ForegroundColor Red
    }
}

$results.Tests.Latency = $latencyResults
Write-Host ""

# ============================================
# Test 2: TCP Throughput
# ============================================
Write-Host "[Test 2] TCP Throughput Testing" -ForegroundColor Yellow

$throughputResults = @()

foreach ($target in $targets) {
    Write-Host "  Testing throughput to $($target.Name)..." -ForegroundColor Gray
    
    # Simulate file transfer (create test file)
    $testFile = "C:\temp\test-10mb.bin"
    $testDir = "C:\temp"
    
    if (!(Test-Path $testDir)) {
        New-Item -ItemType Directory -Path $testDir | Out-Null
    }
    
    # Create 10MB test file
    $bytes = New-Object byte[] (10MB)
    (New-Object Random).NextBytes($bytes)
    [IO.File]::WriteAllBytes($testFile, $bytes)
    
    try {
        # Measure transfer time
        $destination = "\\$($target.Name)\C$\temp\test-received.bin"
        
        $startTime = Get-Date
        Copy-Item -Path $testFile -Destination $destination -ErrorAction Stop
        $endTime = Get-Date
        
        $duration = ($endTime - $startTime).TotalSeconds
        $throughputMbps = (10 * 8) / $duration  # Convert to Mbps
        
        $throughputData = @{
            Target = $target.Name
            TargetType = $target.Type
            FileSizeMB = 10
            TransferTimeSeconds = [math]::Round($duration, 2)
            ThroughputMbps = [math]::Round($throughputMbps, 2)
            Success = $true
        }
        
        Write-Host "    Throughput: $($throughputData.ThroughputMbps) Mbps" -ForegroundColor Green
        
        # Cleanup
        Remove-Item $destination -ErrorAction SilentlyContinue
        
    } catch {
        $throughputData = @{
            Target = $target.Name
            TargetType = $target.Type
            Success = $false
            Error = $_.Exception.Message
        }
        Write-Host "    Transfer failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    $throughputResults += $throughputData
}

# Cleanup test file
Remove-Item $testFile -ErrorAction SilentlyContinue

$results.Tests.Throughput = $throughputResults
Write-Host ""

# ============================================
# Test 3: Authentication Overhead
# ============================================
Write-Host "[Test 3] Authentication Overhead" -ForegroundColor Yellow

$authResults = @()

foreach ($target in $targets) {
    Write-Host "  Testing auth overhead to $($target.Name)..." -ForegroundColor Gray
    
    $authTimes = @()
    
    # Test 10 authentication attempts
    for ($i = 1; $i -le 10; $i++) {
        try {
            $startTime = Get-Date
            
            # Test WinRM authentication
            $session = New-PSSession -ComputerName $target.Name -ErrorAction Stop
            
            $endTime = Get-Date
            $authTime = ($endTime - $startTime).TotalMilliseconds
            
            $authTimes += $authTime
            
            Remove-PSSession $session -ErrorAction SilentlyContinue
            
        } catch {
            # Authentication failed
            Write-Host "    Auth attempt $i failed" -ForegroundColor Gray
        }
        
        Start-Sleep -Milliseconds 200
    }
    
    if ($authTimes.Count -gt 0) {
        $authData = @{
            Target = $target.Name
            TargetType = $target.Type
            SampleCount = $authTimes.Count
            MinAuthTime = [math]::Round(($authTimes | Measure-Object -Minimum).Minimum, 2)
            MaxAuthTime = [math]::Round(($authTimes | Measure-Object -Maximum).Maximum, 2)
            AvgAuthTime = [math]::Round(($authTimes | Measure-Object -Average).Average, 2)
            Success = $true
        }
        
        Write-Host "    Avg auth time: $($authData.AvgAuthTime)ms" -ForegroundColor Green
    } else {
        $authData = @{
            Target = $target.Name
            TargetType = $target.Type
            Success = $false
        }
        Write-Host "    All auth attempts failed" -ForegroundColor Red
    }
    
    $authResults += $authData
}

$results.Tests.Authentication = $authResults
Write-Host ""

# ============================================
# Test 4: Resource Utilization
# ============================================
Write-Host "[Test 4] Resource Utilization" -ForegroundColor Yellow

$cpuSamples = (Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 10).CounterSamples
$avgCPU = [math]::Round(($cpuSamples | Measure-Object -Property CookedValue -Average).Average, 2)

$memTotal = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB
$memAvailable = (Get-Counter '\Memory\Available MBytes').CounterSamples[0].CookedValue / 1024
$memUsedPercent = [math]::Round((($memTotal - $memAvailable) / $memTotal) * 100, 2)

$results.Tests.ResourceUtilization = @{
    CPU = @{
        AveragePercent = $avgCPU
        Samples = 10
    }
    Memory = @{
        TotalGB = [math]::Round($memTotal, 2)
        UsedPercent = $memUsedPercent
    }
}

Write-Host "  CPU Usage: $avgCPU%" -ForegroundColor Green
Write-Host "  Memory Usage: $memUsedPercent%" -ForegroundColor Green
Write-Host ""

# Save results
$results | ConvertTo-Json -Depth 10 | Out-File -FilePath $resultsFile -Encoding UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Performance testing complete"
Write-Host "Results saved to: $resultsFile"
Write-Host "========================================" -ForegroundColor Cyan

return $results
