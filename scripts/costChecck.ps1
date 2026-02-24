# File: Find-UnusedResources.ps1

#Requires -Modules Az.Accounts, Az.Compute, Az.Network, Az.Storage

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [int]$DaysThreshold = 30,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\CostOptimizationReport.html"
)

# Helper function to estimate disk costs
function Get-DiskMonthlyCost {
    param(
        [int]$DiskSize,
        [string]$DiskSku
    )
    
    # Simplified pricing (you should update with actual regional pricing)
    $pricePerGB = switch ($DiskSku) {
        'Premium_LRS' { 0.135 }
        'StandardSSD_LRS' { 0.075 }
        'Standard_LRS' { 0.040 }
        default { 0.040 }
    }
    
    return $DiskSize * $pricePerGB
}

# HTML Report Generator
function Generate-HTMLReport {
    param($Results)
    
    # Defensive null handling
    $totalSavings = if ($Results -and $Results.TotalPotentialSavings) {
        $Results.TotalPotentialSavings
    } else { 0 }

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Azure Cost Optimization Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        h1 { color: #0078d4; }
        h2 { color: #333; border-bottom: 2px solid #0078d4; padding-bottom: 5px; }
        .summary { background: white; padding: 20px; border-radius: 5px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .savings { font-size: 24px; color: #107c10; font-weight: bold; }
        table { border-collapse: collapse; width: 100%; background: white; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        th { background-color: #0078d4; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ddd; }
        tr:hover { background-color: #f5f5f5; }
        .timestamp { color: #666; font-size: 12px; }
    </style>
</head>
<body>
    <h1>Azure Cost Optimization Report</h1>
    <div class="timestamp">Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</div>
    
    <div class="summary">
        <h2>Summary</h2>
        <p>Total Potential Monthly Savings: <span class="savings">`$$($totalSavings.ToString('F2'))</span></p>
        <ul>
            <li>Orphaned Disks: $($Results.OrphanedDisks.Count)</li>
            <li>Unused Public IPs: $($Results.UnusedPublicIPs.Count)</li>
            <li>Stopped VMs: $($Results.StoppedVMs.Count)</li>
            <li>Old Snapshots: $($Results.OldSnapshots.Count)</li>
            <li>Unused NICs: $($Results.UnusedNICs.Count)</li>
        </ul>
    </div>
    
    <h2>Orphaned Disks</h2>
    <table>
        <tr>
            <th>Name</th>
            <th>Resource Group</th>
            <th>Size</th>
            <th>SKU</th>
            <th>Location</th>
            <th>Monthly Cost</th>
        </tr>
        $(foreach ($disk in $Results.OrphanedDisks) {
            "<tr><td>$($disk.Name)</td><td>$($disk.ResourceGroup)</td><td>$($disk.Size)</td><td>$($disk.Sku)</td><td>$($disk.Location)</td><td>`$$($disk.MonthlyCost.ToString('F2'))</td></tr>"
        })
    </table>
    
    <h2>Unused Public IPs</h2>
    <table>
        <tr>
            <th>Name</th>
            <th>Resource Group</th>
            <th>IP Address</th>
            <th>Location</th>
            <th>Monthly Cost</th>
        </tr>
        $(foreach ($pip in $Results.UnusedPublicIPs) {
            "<tr><td>$($pip.Name)</td><td>$($pip.ResourceGroup)</td><td>$($pip.IPAddress)</td><td>$($pip.Location)</td><td>`$$($pip.MonthlyCost.ToString('F2'))</td></tr>"
        })
    </table>
    
    <h2>Stopped VMs (Still Incurring Disk Costs)</h2>
    <table>
        <tr>
            <th>Name</th>
            <th>Resource Group</th>
            <th>Status</th>
            <th>Disk Monthly Cost</th>
        </tr>
        $(foreach ($vm in $Results.StoppedVMs) {
            "<tr><td>$($vm.Name)</td><td>$($vm.ResourceGroup)</td><td>$($vm.Status)</td><td>`$$($vm.DiskMonthlyCost.ToString('F2'))</td></tr>"
        })
    </table>
    
</body>
</html>
"@
    
    return $html
}

# -----------------------
# Connect to Azure
# -----------------------
# Connect-AzAccount  # Uncomment for local runs

if ($SubscriptionId) {
    Set-AzContext -SubscriptionId $SubscriptionId
}

# -----------------------
# Initialize results
# -----------------------
$results = [PSCustomObject]@{
    OrphanedDisks = @()
    UnusedPublicIPs = @()
    StoppedVMs = @()
    OldSnapshots = @()
    UnusedNICs = @()
    TotalPotentialSavings = 0
}

# -----------------------
# Find orphaned managed disks
# -----------------------
Write-Host "Scanning for orphaned disks..." -ForegroundColor Cyan
$disks = Get-AzDisk
foreach ($disk in $disks) {
    if ($disk.ManagedBy -eq $null) {
        $cost = Get-DiskMonthlyCost -DiskSize $disk.DiskSizeGB -DiskSku $disk.Sku.Name
        $results.OrphanedDisks += [PSCustomObject]@{
            Name = $disk.Name
            ResourceGroup = $disk.ResourceGroupName
            Size = "$($disk.DiskSizeGB) GB"
            Sku = $disk.Sku.Name
            Location = $disk.Location
            MonthlyCost = $cost
            CreatedDate = $disk.TimeCreated
        }
        $results.TotalPotentialSavings += $cost
    }
}

# -----------------------
# Find unused public IPs
# -----------------------
Write-Host "Scanning for unused public IPs..." -ForegroundColor Cyan
$publicIPs = Get-AzPublicIpAddress
foreach ($pip in $publicIPs) {
    if ($pip.IpConfiguration -eq $null) {
        $cost = 3.65
        $results.UnusedPublicIPs += [PSCustomObject]@{
            Name = $pip.Name
            ResourceGroup = $pip.ResourceGroupName
            Location = $pip.Location
            IPAddress = $pip.IpAddress
            MonthlyCost = $cost
        }
        $results.TotalPotentialSavings += $cost
    }
}

# -----------------------
# Find stopped VMs
# -----------------------
Write-Host "Scanning for stopped VMs..." -ForegroundColor Cyan
$vms = Get-AzVM -Status
foreach ($vm in $vms) {
    $status = $vm.PowerState
    if ($status -eq "VM deallocated" -or $status -eq "VM stopped") {
        $vmDetails = Get-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name
        $diskCost = 0
        
        $osDisk = Get-AzDisk -ResourceGroupName $vm.ResourceGroupName -DiskName $vmDetails.StorageProfile.OsDisk.Name
        $diskCost += Get-DiskMonthlyCost -DiskSize $osDisk.DiskSizeGB -DiskSku $osDisk.Sku.Name
        
        foreach ($dataDisk in $vmDetails.StorageProfile.DataDisks) {
            $disk = Get-AzDisk -ResourceGroupName $vm.ResourceGroupName -DiskName $dataDisk.Name
            $diskCost += Get-DiskMonthlyCost -DiskSize $disk.DiskSizeGB -DiskSku $disk.Sku.Name
        }
        
        $results.StoppedVMs += [PSCustomObject]@{
            Name = $vm.Name
            ResourceGroup = $vm.ResourceGroupName
            Status = $status
            Location = $vm.Location
            DiskMonthlyCost = $diskCost
            LastStatusChange = $vm.StatusChangeTime
        }
        $results.TotalPotentialSavings += $diskCost
    }
}

# -----------------------
# Find old snapshots
# -----------------------
Write-Host "Scanning for old snapshots..." -ForegroundColor Cyan
$snapshots = Get-AzSnapshot
$cutoffDate = (Get-Date).AddDays(-$DaysThreshold)
foreach ($snapshot in $snapshots) {
    if ($snapshot.TimeCreated -lt $cutoffDate) {
        $cost = ($snapshot.DiskSizeGB / 1024) * 0.05
        $results.OldSnapshots += [PSCustomObject]@{
            Name = $snapshot.Name
            ResourceGroup = $snapshot.ResourceGroupName
            Size = "$($snapshot.DiskSizeGB) GB"
            Created = $snapshot.TimeCreated
            Age = ((Get-Date) - $snapshot.TimeCreated).Days
            MonthlyCost = $cost
        }
        $results.TotalPotentialSavings += $cost
    }
}

# -----------------------
# Find unused NICs
# -----------------------
Write-Host "Scanning for unused network interfaces..." -ForegroundColor Cyan
$nics = Get-AzNetworkInterface
foreach ($nic in $nics) {
    if ($nic.VirtualMachine -eq $null) {
        $results.UnusedNICs += [PSCustomObject]@{
            Name = $nic.Name
            ResourceGroup = $nic.ResourceGroupName
            Location = $nic.Location
            PrivateIP = $nic.IpConfigurations[0].PrivateIpAddress
        }
    }
}

# -----------------------
# Generate HTML Report AFTER all scans
# -----------------------
$htmlReport = Generate-HTMLReport -Results $results
$htmlReport | Out-File -FilePath $OutputPath -Encoding UTF8

Write-Host "`nReport generated: $OutputPath" -ForegroundColor Green
Write-Host "Total potential monthly savings: `$$($results.TotalPotentialSavings.ToString('F2'))" -ForegroundColor Yellow

return $results
