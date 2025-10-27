# Master Data Collection Script
# Part of my MSc research project evaluating Azure micro-segmentation
# Orchestrates attack simulation and performance testing
# Collects all security and performance metrics for statistical analysis

param(
    [Parameter(Mandatory=$true)]
    [string]$ConfigName,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "C:\ResearchData"
)

New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Data Collection - $ConfigName"
Write-Host "Time: $timestamp"
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Run attack simulation
Write-Host "Running attack simulation..." -ForegroundColor Yellow
$attackResults = & "$PSScriptRoot\Invoke-LateralMovementTest.ps1" -ConfigName $ConfigName -OutputPath $OutputPath

Write-Host ""
Write-Host "Waiting for logs to propagate..." -ForegroundColor Yellow
Start-Sleep -Seconds 300

# Run performance tests
Write-Host "Running performance tests..." -ForegroundColor Yellow
$perfResults = & "$PSScriptRoot\Measure-Performance.ps1" -ConfigName $ConfigName -OutputPath $OutputPath

# Collect Azure Monitor logs
Write-Host ""
Write-Host "Collecting Azure Monitor logs..." -ForegroundColor Yellow

# Query security events
$query = @"
SecurityEvent
| where TimeGenerated > ago(2h)
| where EventID in (4624, 4625, 4648, 4672, 5140, 5145)
| summarize count() by EventID, Account, Computer
"@

Write-Host "  Query: Security events from last 2 hours" -ForegroundColor Gray

# Save query for manual execution
$queryFile = Join-Path $OutputPath "azure-monitor-query-$ConfigName-$timestamp.kql"
$query | Out-File -FilePath $queryFile -Encoding UTF8

Write-Host "  Query saved to: $queryFile" -ForegroundColor Green
Write-Host "  Run this query in Azure Monitor Log Analytics" -ForegroundColor Yellow

# Generate summary report
Write-Host ""
Write-Host "Generating summary report..." -ForegroundColor Yellow

$summary = @{
    Configuration = $ConfigName
    Timestamp = $timestamp
    AttackSimulation = @{
        LateralMovementSuccessRate = $attackResults.Metrics.LateralMovementSuccessRate
        TotalAttempts = $attackResults.Metrics.TotalLateralMovementAttempts
        Successful = $attackResults.Metrics.SuccessfulLateralMovements
    }
    Performance = @{
        AvgLatencyMs = if ($perfResults.Tests.Latency) {
            [math]::Round(($perfResults.Tests.Latency | ForEach-Object { $_.AvgLatency } | Measure-Object -Average).Average, 2)
        } else { $null }
        AvgThroughputMbps = if ($perfResults.Tests.Throughput) {
            [math]::Round(($perfResults.Tests.Throughput | Where-Object { $_.Success } | ForEach-Object { $_.ThroughputMbps } | Measure-Object -Average).Average, 2)
        } else { $null }
        AvgAuthTimeMs = if ($perfResults.Tests.Authentication) {
            [math]::Round(($perfResults.Tests.Authentication | Where-Object { $_.Success } | ForEach-Object { $_.AvgAuthTime } | Measure-Object -Average).Average, 2)
        } else { $null }
    }
}

$summaryFile = Join-Path $OutputPath "summary-$ConfigName-$timestamp.json"
$summary | ConvertTo-Json -Depth 5 | Out-File -FilePath $summaryFile -Encoding UTF8

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Data Collection Complete"
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Files generated:"
Write-Host "  - Attack results"
Write-Host "  - Performance results"
Write-Host "  - Azure Monitor query"
Write-Host "  - Summary report: $summaryFile"
Write-Host ""

return $summary
