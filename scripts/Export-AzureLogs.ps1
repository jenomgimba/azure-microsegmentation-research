# Export Azure Logs - Exports flow logs and security events to local storage

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("baseline", "config1", "config2", "config3")]
    [string]$ConfigName,

    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "..\ResearchData",

    [Parameter(Mandatory=$false)]
    [int]$LookbackHours = 24
)

$ErrorActionPreference = "Continue"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

# Configuration mapping
$configMap = @{
    "baseline" = @{
        ResourceGroup = "rg-segmentation-baseline"
        StorageAccount = "stflowlogsbaseline"
        Workspace = "law-baseline"
    }
    "config1" = @{
        ResourceGroup = "rg-segmentation-config1-nsg"
        StorageAccount = "stflowlogsconfig1"
        Workspace = "law-config1"
    }
    "config2" = @{
        ResourceGroup = "rg-segmentation-config2-asg"
        StorageAccount = "stflowlogsconfig2"
        Workspace = "law-config2"
    }
    "config3" = @{
        ResourceGroup = "rg-segmentation-config3-firewall"
        StorageAccount = "stflowlogsconfig3"
        Workspace = "law-config3"
    }
}

$config = $configMap[$ConfigName]
$exportFolder = Join-Path $OutputPath "logs-export-$ConfigName-$timestamp"

Write-Host "`n=== Azure Log Export for $ConfigName ===" -ForegroundColor Cyan
Write-Host "Output: $exportFolder" -ForegroundColor Gray

# Create export directory
New-Item -ItemType Directory -Path $exportFolder -Force | Out-Null
New-Item -ItemType Directory -Path "$exportFolder\flowlogs" -Force | Out-Null
New-Item -ItemType Directory -Path "$exportFolder\security-events" -Force | Out-Null
New-Item -ItemType Directory -Path "$exportFolder\sentinel" -Force | Out-Null

# Check and install Azure PowerShell module if needed
Write-Host "Checking Azure PowerShell module..." -ForegroundColor Gray
$azModule = Get-Module -ListAvailable -Name Az.Accounts

if (-not $azModule) {
    Write-Host "Azure PowerShell module not found. Installing..." -ForegroundColor Yellow
    try {
        Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
        Write-Host "Azure PowerShell module installed successfully" -ForegroundColor Green
    } catch {
        Write-Host "Failed to install Azure PowerShell module: $_" -ForegroundColor Red
        Write-Host "Please install manually: Install-Module -Name Az -Scope CurrentUser" -ForegroundColor Yellow
        exit 1
    }
}

# Import Az module
Import-Module Az.Accounts -ErrorAction SilentlyContinue
Import-Module Az.Storage -ErrorAction SilentlyContinue
Import-Module Az.OperationalInsights -ErrorAction SilentlyContinue

# Check if logged in to Azure
try {
    $context = Get-AzContext -ErrorAction Stop
    if (-not $context) {
        Write-Host "Not logged in to Azure. Attempting to connect..." -ForegroundColor Yellow
        Connect-AzAccount -ErrorAction Stop
        $context = Get-AzContext
    }
    Write-Host "Subscription: $($context.Subscription.Name)" -ForegroundColor Gray
} catch {
    Write-Host "Failed to connect to Azure: $_" -ForegroundColor Red
    Write-Host "Please login manually: Connect-AzAccount" -ForegroundColor Yellow
    exit 1
}

# 1. Export NSG Flow Logs from Storage Account
Write-Host "`n[1/4] Exporting NSG Flow Logs..." -ForegroundColor Yellow
try {
    $storageAccount = Get-AzStorageAccount -ResourceGroupName $config.ResourceGroup -Name $config.StorageAccount -ErrorAction Stop
    $ctx = $storageAccount.Context

    # VNet Flow logs are stored in: insights-logs-flowlogflowevent container
    # (NSG flow logs used: insights-logs-networksecuritygroupflowevent - deprecated)
    $containerName = "insights-logs-flowlogflowevent"

    # Get all blobs (flow log files) from last 24 hours
    $blobs = Get-AzStorageBlob -Container $containerName -Context $ctx -ErrorAction SilentlyContinue

    if ($blobs) {
        $recentBlobs = $blobs | Where-Object { $_.LastModified -gt (Get-Date).AddHours(-$LookbackHours) }

        Write-Host "  Found $($recentBlobs.Count) flow log files from last $LookbackHours hours" -ForegroundColor Gray

        $flowLogData = @()
        foreach ($blob in $recentBlobs) {
            $localFile = Join-Path "$exportFolder\flowlogs" $blob.Name.Replace("/", "_")
            Get-AzStorageBlobContent -Blob $blob.Name -Container $containerName -Context $ctx -Destination $localFile -Force | Out-Null

            # Parse JSON and add to collection
            $content = Get-Content $localFile -Raw | ConvertFrom-Json
            $flowLogData += $content
        }

        # Save consolidated flow logs
        $flowLogData | ConvertTo-Json -Depth 10 | Out-File "$exportFolder\flowlogs-consolidated.json" -Encoding UTF8
        Write-Host "  Exported flow logs to: flowlogs-consolidated.json" -ForegroundColor Green
    } else {
        Write-Host "  No flow logs found (container may not exist yet)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  Failed to export flow logs: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 2. Export Security Events from Log Analytics
Write-Host "`n[2/4] Exporting Security Events..." -ForegroundColor Yellow
try {
    $workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $config.ResourceGroup -Name $config.Workspace -ErrorAction Stop

    $queries = @{
        "logon-events" = @"
SecurityEvent
| where TimeGenerated > ago($($LookbackHours)h)
| where EventID in (4624, 4625, 4648, 4672, 4720, 4732, 4776, 5140, 5145)
| project TimeGenerated, Computer, EventID, Account, LogonType, IpAddress, IpPort, TargetUserName, TargetDomainName, Status, SubStatus, FailureReason, ProcessName, ShareName, RelativeTargetName, AccessMask
| order by TimeGenerated desc
"@
        "lateral-movement" = @"
SecurityEvent
| where TimeGenerated > ago($($LookbackHours)h)
| where EventID in (4648, 5140, 5145)
| project TimeGenerated, Computer, EventID, Account, TargetUserName, IpAddress, ShareName, RelativeTargetName, ProcessName
| order by TimeGenerated desc
"@
        "failed-logons" = @"
SecurityEvent
| where TimeGenerated > ago($($LookbackHours)h)
| where EventID == 4625
| project TimeGenerated, Computer, Account, IpAddress, LogonType, Status, SubStatus, FailureReason
| order by TimeGenerated desc
"@
        "network-shares" = @"
SecurityEvent
| where TimeGenerated > ago($($LookbackHours)h)
| where EventID in (5140, 5145)
| project TimeGenerated, Computer, Account, IpAddress, ShareName, RelativeTargetName, AccessMask
| order by TimeGenerated desc
"@
    }

    # Store results in variables for detection metrics
    $logonEvents = $null
    $lateralMovementEvents = $null
    $failedLogons = $null
    $networkShares = $null

    foreach ($queryName in $queries.Keys) {
        $query = $queries[$queryName]

        Write-Host "  Querying: $queryName..." -ForegroundColor Gray
        $results = Invoke-AzOperationalInsightsQuery -WorkspaceId $workspace.CustomerId -Query $query -ErrorAction Stop

        if ($results.Results) {
            $results.Results | ConvertTo-Json -Depth 5 | Out-File "$exportFolder\security-events\$queryName.json" -Encoding UTF8
            $results.Results | Export-Csv "$exportFolder\security-events\$queryName.csv" -NoTypeInformation -Encoding UTF8
            Write-Host "    Exported $($results.Results.Count) events" -ForegroundColor Green

            # Store results for detection metrics
            switch ($queryName) {
                "logon-events" { $logonEvents = $results.Results }
                "lateral-movement" { $lateralMovementEvents = $results.Results }
                "failed-logons" { $failedLogons = $results.Results }
                "network-shares" { $networkShares = $results.Results }
            }
        } else {
            Write-Host "    No events found" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "  Failed to export security events: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 3. Export Traffic Analytics Data
Write-Host "`n[3/4] Exporting Traffic Analytics..." -ForegroundColor Yellow
$trafficFlows = $null
try {
    $trafficQuery = @"
AzureNetworkAnalytics_CL
| where TimeGenerated > ago($($LookbackHours)h)
| where SubType_s == "FlowLog"
| project TimeGenerated, FlowStartTime_t, FlowEndTime_t, FlowType_s, SrcIP_s, DestIP_s, DestPort_d, L7Protocol_s, FlowStatus_s, NSGRuleResult_s = NSGRule_s, VMName_s, Subnet_s, NIC_s
| order by TimeGenerated desc
"@

    $results = Invoke-AzOperationalInsightsQuery -WorkspaceId $workspace.CustomerId -Query $trafficQuery -ErrorAction Stop

    if ($results.Results) {
        $trafficFlows = $results.Results
        $results.Results | ConvertTo-Json -Depth 5 | Out-File "$exportFolder\traffic-analytics.json" -Encoding UTF8
        $results.Results | Export-Csv "$exportFolder\traffic-analytics.csv" -NoTypeInformation -Encoding UTF8
        Write-Host "  Exported $($results.Results.Count) traffic flows" -ForegroundColor Green
    } else {
        Write-Host "  No traffic analytics data found" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  Failed to export traffic analytics: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 4. Export Sentinel Incidents and Alerts
Write-Host "`n[4/4] Exporting Sentinel Incidents..." -ForegroundColor Yellow
try {
    $incidentsQuery = @"
SecurityIncident
| where TimeGenerated > ago($($LookbackHours)h)
| project TimeGenerated, IncidentNumber, Title, Description, Severity, Status, Owner, Classification, ClassificationComment, ClassificationReason, ProviderName, Tactics, Techniques
| order by TimeGenerated desc
"@

    $alertsQuery = @"
SecurityAlert
| where TimeGenerated > ago($($LookbackHours)h)
| project TimeGenerated, AlertName, AlertSeverity, Description, Tactics, Techniques, CompromisedEntity, RemediationSteps, ExtendedProperties
| order by TimeGenerated desc
"@

    $incidents = Invoke-AzOperationalInsightsQuery -WorkspaceId $workspace.CustomerId -Query $incidentsQuery -ErrorAction Stop
    $alerts = Invoke-AzOperationalInsightsQuery -WorkspaceId $workspace.CustomerId -Query $alertsQuery -ErrorAction Stop

    if ($incidents.Results) {
        $incidents.Results | ConvertTo-Json -Depth 5 | Out-File "$exportFolder\sentinel\incidents.json" -Encoding UTF8
        $incidents.Results | Export-Csv "$exportFolder\sentinel\incidents.csv" -NoTypeInformation -Encoding UTF8
        Write-Host "  Exported $($incidents.Results.Count) incidents" -ForegroundColor Green
    } else {
        Write-Host "  No Sentinel incidents found" -ForegroundColor Yellow
    }

    if ($alerts.Results) {
        $alerts.Results | ConvertTo-Json -Depth 5 | Out-File "$exportFolder\sentinel\alerts.json" -Encoding UTF8
        $alerts.Results | Export-Csv "$exportFolder\sentinel\alerts.csv" -NoTypeInformation -Encoding UTF8
        Write-Host "  Exported $($alerts.Results.Count) alerts" -ForegroundColor Green
    } else {
        Write-Host "  No Sentinel alerts found" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  Failed to export Sentinel data: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Calculate detection rate
Write-Host "`n[5/4] Calculating detection rate..." -ForegroundColor Yellow

$detectionMetrics = @{
    TotalSecurityEvents = 0
    LateralMovementEvents = 0
    FailedLogonEvents = 0
    NetworkShareEvents = 0
    TrafficFlows = 0
    SentinelIncidents = 0
    SentinelAlerts = 0
    DetectionRate = 0
}

if ($logonEvents) { $detectionMetrics.TotalSecurityEvents = @($logonEvents).Count }
if ($lateralMovementEvents) { $detectionMetrics.LateralMovementEvents = @($lateralMovementEvents).Count }
if ($failedLogons) { $detectionMetrics.FailedLogonEvents = @($failedLogons).Count }
if ($networkShares) { $detectionMetrics.NetworkShareEvents = @($networkShares).Count }
if ($trafficFlows) { $detectionMetrics.TrafficFlows = @($trafficFlows).Count }
if ($incidents.Results) { $detectionMetrics.SentinelIncidents = @($incidents.Results).Count }
if ($alerts.Results) { $detectionMetrics.SentinelAlerts = @($alerts.Results).Count }

# Calculate overall detection rate
# Detection is considered successful if any log type captured events
$totalLogSources = 7  # logonEvents, lateralMovement, failedLogons, networkShares, trafficFlows, incidents, alerts
$activeSources = 0

if ($detectionMetrics.TotalSecurityEvents -gt 0) { $activeSources++ }
if ($detectionMetrics.LateralMovementEvents -gt 0) { $activeSources++ }
if ($detectionMetrics.FailedLogonEvents -gt 0) { $activeSources++ }
if ($detectionMetrics.NetworkShareEvents -gt 0) { $activeSources++ }
if ($detectionMetrics.TrafficFlows -gt 0) { $activeSources++ }
if ($detectionMetrics.SentinelIncidents -gt 0) { $activeSources++ }
if ($detectionMetrics.SentinelAlerts -gt 0) { $activeSources++ }

$detectionMetrics.DetectionRate = [math]::Round(($activeSources / $totalLogSources) * 100, 2)

Write-Host "  Detection Coverage:" -ForegroundColor Gray
Write-Host "    Security Events: $($detectionMetrics.TotalSecurityEvents)" -ForegroundColor Gray
Write-Host "    Lateral Movement Events: $($detectionMetrics.LateralMovementEvents)" -ForegroundColor Gray
Write-Host "    Failed Logons: $($detectionMetrics.FailedLogonEvents)" -ForegroundColor Gray
Write-Host "    Network Share Access: $($detectionMetrics.NetworkShareEvents)" -ForegroundColor Gray
Write-Host "    Traffic Flows: $($detectionMetrics.TrafficFlows)" -ForegroundColor Gray
Write-Host "    Sentinel Incidents: $($detectionMetrics.SentinelIncidents)" -ForegroundColor Gray
Write-Host "    Sentinel Alerts: $($detectionMetrics.SentinelAlerts)" -ForegroundColor Gray
Write-Host "    Detection Rate: $($detectionMetrics.DetectionRate)%" -ForegroundColor $(if ($detectionMetrics.DetectionRate -gt 70) { "Green" } else { "Yellow" })

# Save detection metrics
$detectionMetrics | ConvertTo-Json -Depth 5 | Out-File "$exportFolder\detection-metrics.json" -Encoding UTF8
$detectionMetrics | Export-Csv "$exportFolder\detection-metrics.csv" -NoTypeInformation -Encoding UTF8

# Create summary report
$summary = @{
    ConfigName = $ConfigName
    ExportTimestamp = $timestamp
    LookbackHours = $LookbackHours
    ResourceGroup = $config.ResourceGroup
    ExportLocation = $exportFolder
    FilesCreated = (Get-ChildItem -Path $exportFolder -Recurse -File).Count
    DetectionMetrics = $detectionMetrics
}

$summary | ConvertTo-Json -Depth 5 | Out-File "$exportFolder\export-summary.json" -Encoding UTF8

Write-Host "`n=== Export Complete ===" -ForegroundColor Green
Write-Host "Total files exported: $($summary.FilesCreated)" -ForegroundColor Gray
Write-Host "Detection rate: $($detectionMetrics.DetectionRate)%" -ForegroundColor $(if ($detectionMetrics.DetectionRate -gt 70) { "Green" } else { "Yellow" })
Write-Host "Location: $exportFolder" -ForegroundColor Gray
Write-Host "`nYou can now safely run 'terraform destroy'" -ForegroundColor Cyan
