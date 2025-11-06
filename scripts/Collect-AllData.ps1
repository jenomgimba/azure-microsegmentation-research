# Data Collection Script - Runs attack simulations and performance tests

param(
    [Parameter(Mandatory=$true)]
    [string]$ConfigName,

    [Parameter(Mandatory=$false)]
    [int]$Iteration = 0,

    [Parameter(Mandatory=$false)]
    [int]$Iterations = 0,

    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "C:\ResearchData",

    [Parameter(Mandatory=$false)]
    [int]$DelayBetweenIterations = 60
)

New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null

# If Iterations parameter is specified, loop multiple times
if ($Iterations -gt 0) {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Multi-Iteration Data Collection - $ConfigName"
    Write-Host "Running $Iterations iterations with ${DelayBetweenIterations}s delay between runs"
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    for ($i = 1; $i -le $Iterations; $i++) {
        Write-Host "`n>>> Starting Iteration $i of $Iterations <<<`n" -ForegroundColor Yellow

        # Run single iteration
        & $PSCommandPath -ConfigName $ConfigName -Iteration $i -OutputPath $OutputPath

        # Delay between iterations
        if ($i -lt $Iterations) {
            Write-Host "`nWaiting ${DelayBetweenIterations} seconds before next iteration..." -ForegroundColor Gray
            Start-Sleep -Seconds $DelayBetweenIterations
        }
    }

    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "All $Iterations iterations complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Run Export-AzureLogs.ps1 -ConfigName '$ConfigName' to export logs locally"
    Write-Host "  2. Run terraform destroy to clean up resources"
    Write-Host "  3. After all configs complete, run: python analyze-results-enhanced.py"
    Write-Host ""

    return
}

# Auto-detect iteration number if not specified
if ($Iteration -eq 0) {
    $existingFiles = Get-ChildItem -Path $OutputPath -Filter "summary-$ConfigName-run*-*.json" -ErrorAction SilentlyContinue
    if ($existingFiles) {
        $maxIteration = ($existingFiles | ForEach-Object {
            if ($_.Name -match "run(\d+)-") { [int]$matches[1] }
        } | Measure-Object -Maximum).Maximum
        $Iteration = $maxIteration + 1
    } else {
        $Iteration = 1
    }
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runLabel = "$ConfigName-run$Iteration"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Data Collection - $ConfigName"
Write-Host "Iteration: $Iteration of 5 (recommended)"
Write-Host "Time: $timestamp"
Write-Host "Steps: 5 (baseline perf, attacks, wait, attack perf, summary)"
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Baseline Performance (no attacks) - Only run on first iteration
if ($Iteration -eq 1) {
    Write-Host "[1/5] Running baseline performance tests (no attacks)..." -ForegroundColor Yellow
    try {
        $baselinePerf = & "$PSScriptRoot\Measure-Performance.ps1" -ConfigName $runLabel -OutputPath $OutputPath -BaselineOnly
        Write-Host "  Baseline performance measurement complete" -ForegroundColor Green
    } catch {
        Write-Host "  Warning: Baseline performance test failed: $_" -ForegroundColor Red
        $baselinePerf = $null
    }
    Write-Host ""
} else {
    Write-Host "[1/5] Skipping baseline performance test (only needed for iteration 1)" -ForegroundColor Gray
    Write-Host ""
    $baselinePerf = $null
}

# Step 2: Bidirectional Lateral Movement Testing
Write-Host "[2/5] Running bidirectional lateral movement tests..." -ForegroundColor Yellow
$attackResults = @()

# Attack from Web tier
Write-Host "  Testing lateral movement from Web tier (vm-web-1)..." -ForegroundColor Gray
try {
    $webAttack = & "$PSScriptRoot\Invoke-LateralMovementTest.ps1" -ConfigName $runLabel -OutputPath $OutputPath -SourceVM "vm-web-1"
    $attackResults += $webAttack
    Write-Host "    Complete: Web -> App, Web -> DB" -ForegroundColor Green
} catch {
    Write-Host "    Warning: Web tier attack failed: $_" -ForegroundColor Red
}

Start-Sleep -Seconds 30

# Attack from App tier
Write-Host "  Testing lateral movement from App tier (vm-app-1)..." -ForegroundColor Gray
try {
    $appAttack = & "$PSScriptRoot\Invoke-LateralMovementTest.ps1" -ConfigName $runLabel -OutputPath $OutputPath -SourceVM "vm-app-1"
    $attackResults += $appAttack
    Write-Host "    Complete: App -> Web, App -> DB" -ForegroundColor Green
} catch {
    Write-Host "    Warning: App tier attack failed: $_" -ForegroundColor Red
}

Start-Sleep -Seconds 30

# Attack from Database tier
Write-Host "  Testing lateral movement from Database tier (vm-db-1)..." -ForegroundColor Gray
try {
    $dbAttack = & "$PSScriptRoot\Invoke-LateralMovementTest.ps1" -ConfigName $runLabel -OutputPath $OutputPath -SourceVM "vm-db-1"
    $attackResults += $dbAttack
    Write-Host "    Complete: DB -> Web, DB -> App" -ForegroundColor Green
} catch {
    Write-Host "    Warning: Database tier attack failed: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "  Bidirectional testing complete: 6 attack paths tested" -ForegroundColor Green
Write-Host ""

# Step 3: Wait for logs to propagate
Write-Host "[3/5] Waiting for security logs to propagate to Log Analytics..." -ForegroundColor Yellow
Write-Host "  Waiting 5 minutes for log ingestion..." -ForegroundColor Gray
Start-Sleep -Seconds 300

# Step 4: Performance tests with attack impact
Write-Host "[4/5] Running performance tests (measuring attack impact)..." -ForegroundColor Yellow
try {
    $attackPerf = & "$PSScriptRoot\Measure-Performance.ps1" -ConfigName $runLabel -OutputPath $OutputPath
    Write-Host "  Performance measurement with attacks complete" -ForegroundColor Green
} catch {
    Write-Host "  Warning: Attack performance test failed: $_" -ForegroundColor Red
    $attackPerf = $null
}

Write-Host ""

# Step 5: Generate comprehensive summary
Write-Host "[5/5] Generating comprehensive summary report..." -ForegroundColor Yellow

# Calculate aggregate metrics
$totalAttempts = 0
$totalSuccessful = 0
$totalBlocked = 0

foreach ($result in $attackResults) {
    if ($result -and $result.Metrics) {
        $totalAttempts += $result.Metrics.TotalLateralMovementAttempts
        $totalSuccessful += $result.Metrics.SuccessfulLateralMovements
        $totalBlocked += $result.Metrics.BlockedLateralMovements
    }
}

$blockRate = if ($totalAttempts -gt 0) {
    [math]::Round(($totalBlocked / $totalAttempts) * 100, 2)
} else { 0 }

$summary = @{
    Configuration = $ConfigName
    Iteration = $Iteration
    Timestamp = $timestamp
    AttackSimulation = @{
        BidirectionalTesting = $true
        AttackPaths = 6
        TotalAttempts = $totalAttempts
        Successful = $totalSuccessful
        Blocked = $totalBlocked
        BlockRate = $blockRate
        Techniques = @("RDP", "SMB", "PSRemoting", "WMI", "ScheduledTask", "Service")
    }
    Performance = @{
        Baseline = if ($baselinePerf -and $baselinePerf.Metrics) {
            @{
                AvgLatencyMs = $baselinePerf.Metrics.AverageLatencyMs
                AvgThroughputMbps = $baselinePerf.Metrics.AverageThroughputMbps
                AvgCpuPercent = $baselinePerf.Metrics.AverageCpuPercent
                AvgMemoryPercent = $baselinePerf.Metrics.AverageMemoryPercent
            }
        } else { $null }
        WithAttacks = if ($attackPerf -and $attackPerf.Metrics) {
            @{
                AvgLatencyMs = $attackPerf.Metrics.AverageLatencyMs
                AvgThroughputMbps = $attackPerf.Metrics.AverageThroughputMbps
                AvgCpuPercent = $attackPerf.Metrics.AverageCpuPercent
                AvgMemoryPercent = $attackPerf.Metrics.AverageMemoryPercent
            }
        } else { $null }
        OverheadCalculated = ($baselinePerf -ne $null -and $attackPerf -ne $null)
    }
}

$summaryFile = Join-Path $OutputPath "summary-$runLabel-$timestamp.json"
$summary | ConvertTo-Json -Depth 10 | Out-File -FilePath $summaryFile -Encoding UTF8

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Data Collection Complete"
Write-Host "Iteration $Iteration completed for $ConfigName"
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Results Summary:" -ForegroundColor Cyan
Write-Host "  Attack Block Rate: $blockRate%" -ForegroundColor $(if ($blockRate -gt 50) { "Green" } else { "Red" })
Write-Host "  Total Attack Attempts: $totalAttempts (across 6 paths)"
Write-Host "  Blocked: $totalBlocked | Successful: $totalSuccessful"
Write-Host ""
Write-Host "Files generated:"
Write-Host "  - Attack results: attack-results-$runLabel-*.json (3 files)"
if ($baselinePerf) {
    Write-Host "  - Performance results: performance-$runLabel-*.json (2 files - baseline + with attacks)"
} else {
    Write-Host "  - Performance results: performance-$runLabel-*.json (1 file - with attacks)"
}
Write-Host "  - Summary report: $summaryFile"
Write-Host ""
Write-Host "To run next iteration manually:"
Write-Host "  .\Collect-AllData.ps1 -ConfigName '$ConfigName'"
Write-Host ""
Write-Host "Or run all 5 iterations automatically:"
Write-Host "  .\Collect-AllData.ps1 -ConfigName '$ConfigName' -Iterations 5"
Write-Host ""
Write-Host "Recommended: Run 5 iterations total for statistical validity (n=5)"
Write-Host ""

return $summary
