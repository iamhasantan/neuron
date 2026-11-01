# SPDX-FileCopyrightText: 2026 Contributors to neuron
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Read-only Windows hardware/driver snapshot. -ExportRazerDrivers copies existing
# driver packages; it never installs, removes, updates, or disables a driver.

[CmdletBinding()]
param(
    [ValidateSet('Before', 'After')]
    [string]$Stage = 'Before',
    [string]$Destination = (Join-Path $env:LOCALAPPDATA 'neuron\razer-lab'),
    [switch]$ExportRazerDrivers
)

$ErrorActionPreference = 'Stop'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$folder = Join-Path $Destination ('{0}-{1}' -f $Stage.ToLowerInvariant(), $stamp)
New-Item -Path $folder -ItemType Directory -ErrorAction Stop | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding $false

function Write-LabJson {
    param([string]$Name, [object]$Value)
    $json = ConvertTo-Json -InputObject $Value -Depth 8
    [System.IO.File]::WriteAllText((Join-Path $folder $Name), $json + [Environment]::NewLine, $utf8)
}

$drivers = @(Get-CimInstance Win32_PnPSignedDriver |
    Where-Object {
        $_.DeviceID -match '(?i)VID_1532|RZCONTROL|RZVIRTUAL|TUSBAUDIO_ENUM' -or
        $_.DeviceName -match '(?i)Razer|Seiren|Kraken|THX' -or
        $_.DriverProviderName -match '(?i)Razer|THX'
    } |
    Select-Object DeviceName, DeviceID, DriverProviderName, DriverVersion, DriverDate, InfName, Manufacturer)

$devices = @(Get-PnpDevice -PresentOnly |
    Where-Object {
        $_.InstanceId -match '(?i)VID_1532|RZCONTROL|RZVIRTUAL|TUSBAUDIO_ENUM' -or
        $_.FriendlyName -match '(?i)Razer|Seiren|Kraken|THX'
    } |
    ForEach-Object {
        $service = Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName 'DEVPKEY_Device_Service' -ErrorAction SilentlyContinue
        [PSCustomObject]@{
            Name       = $_.FriendlyName
            InstanceId = $_.InstanceId
            Class      = $_.Class
            Status     = $_.Status
            Service    = $service.Data
        }
    })

$services = @(Get-CimInstance Win32_SystemDriver |
    Where-Object {
        $_.Name -match '(?i)^Rz|Razer|THX|Seiren' -or
        $_.DisplayName -match '(?i)Razer|THX|Seiren'
    } |
    Select-Object Name, DisplayName, State, StartMode, PathName)

$audioEndpoints = @(Get-PnpDevice -PresentOnly -Class AudioEndpoint -ErrorAction SilentlyContinue |
    Where-Object { $_.FriendlyName -match '(?i)Razer|Seiren|Kraken|THX' } |
    Select-Object FriendlyName, InstanceId, Status)

$os = Get-CimInstance Win32_OperatingSystem |
    Select-Object Caption, Version, BuildNumber

Write-LabJson 'drivers.json' $drivers
Write-LabJson 'devices.json' $devices
Write-LabJson 'services.json' $services
Write-LabJson 'audio-endpoints.json' $audioEndpoints
Write-LabJson 'windows.json' $os

$backups = @()
if ($ExportRazerDrivers) {
    # Backup is optional, may need elevation, and requires enough disk space.
    # Only the selected OEM packages are exported, not the entire Driver Store.
    $infs = @($drivers |
        Where-Object {
            $_.DriverProviderName -match '(?i)Razer|THX' -and
            $_.InfName -match '(?i)^oem[0-9]+\.inf$'
        } |
        Select-Object -ExpandProperty InfName -Unique)

    $backupDir = Join-Path $folder 'driver-backup'
    New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
    foreach ($inf in $infs) {
        $output = @(& pnputil.exe /export-driver $inf $backupDir 2>&1 | ForEach-Object { $_.ToString() })
        $backups += [PSCustomObject]@{
            InfName  = $inf
            ExitCode = $LASTEXITCODE
            Output   = ($output -join [Environment]::NewLine)
        }
    }
    Write-LabJson 'export-results.json' $backups
}

$summary = [PSCustomObject]@{
    CapturedAt       = (Get-Date).ToString('o')
    Stage            = $Stage
    DeviceCount      = $devices.Count
    DriverCount      = $drivers.Count
    AudioCount       = $audioEndpoints.Count
    BackupRequested  = [bool]$ExportRazerDrivers
    BackupFailures   = @($backups | Where-Object { $_.ExitCode -ne 0 }).Count
    ContainsLocalIds = $true
}
Write-LabJson 'summary.json' $summary
Write-Host ('Razer lab {0} snapshot saved locally: {1}' -f $Stage.ToLowerInvariant(), $folder)
if ($ExportRazerDrivers -and $summary.BackupFailures -gt 0) {
    Write-Warning ('{0} driver exports failed. Review export-results.json before uninstalling.' -f $summary.BackupFailures)
}
Write-Warning 'Keep this folder local. Device IDs and driver information may identify your system.'
