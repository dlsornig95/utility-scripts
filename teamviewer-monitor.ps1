# TeamViewer Connection Monitor
# Monitors TeamViewer connectivity and resets WiFi if connection drops

param(
    [int]$CheckIntervalSeconds = 30,
    [int]$FailuresBeforeReset = 3,
    [int]$WifiOffDurationSeconds = 5,
    [string]$WifiAdapterName = "Wi-Fi",
    [string]$LogFile = "$env:USERPROFILE\.local\bin\teamviewer-monitor.log",
    [int]$MaxConsecutiveResets = 5
)

# =============================================================================
# ALLOWED NETWORKS - Add your home/office WiFi names here
# The monitor will ONLY run when connected to one of these networks
# =============================================================================
$AllowedNetworks = @(
    "SornigHouse"
    # Add more networks below, one per line:
    # "OfficeWiFi"
    # "WorkNetwork"
)
# =============================================================================

# TeamViewer master server endpoints to check connectivity
$TeamViewerServers = @(
    "master1.teamviewer.com",
    "master2.teamviewer.com",
    "master3.teamviewer.com",
    "ping3.teamviewer.com"
)

$TeamViewerLogPath = "C:\Program Files\TeamViewer\TeamViewer15_Logfile.log"
$ConsecutiveFailures = 0
$ConsecutiveResets = 0
$LastLogPosition = 0

function Get-CurrentSSID {
    try {
        $output = netsh wlan show interfaces
        $ssidLine = $output | Select-String -Pattern "^\s*SSID\s*:\s*(.+)$"
        if ($ssidLine) {
            return ($ssidLine.Matches[0].Groups[1].Value).Trim()
        }
    } catch {
        return $null
    }
    return $null
}

function Test-AllowedNetwork {
    $currentSSID = Get-CurrentSSID
    if (-not $currentSSID) {
        return $false
    }
    return $AllowedNetworks -contains $currentSSID
}

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"
    Write-Host $logEntry
    Add-Content -Path $LogFile -Value $logEntry -ErrorAction SilentlyContinue
}

function Test-TeamViewerConnectivity {
    # Method 1: Check if we can reach TeamViewer servers
    foreach ($server in $TeamViewerServers) {
        try {
            $result = Test-Connection -ComputerName $server -Count 1 -Quiet -ErrorAction SilentlyContinue
            if ($result) {
                return $true
            }
        } catch {
            continue
        }
    }

    # Method 2: Check if TeamViewer log is being updated (indicates activity)
    try {
        $logInfo = Get-Item $TeamViewerLogPath -ErrorAction SilentlyContinue
        if ($logInfo) {
            $lastWrite = $logInfo.LastWriteTime
            $timeSinceUpdate = (Get-Date) - $lastWrite

            # If log hasn't been updated in 2 minutes, might be disconnected
            if ($timeSinceUpdate.TotalMinutes -lt 2) {
                return $true
            }
        }
    } catch {
        # Ignore errors reading log
    }

    # Method 3: Check if TeamViewer process is running and responsive
    $tvProcess = Get-Process -Name "TeamViewer" -ErrorAction SilentlyContinue
    if (-not $tvProcess) {
        Write-Log "WARNING: TeamViewer process not found"
        return $false
    }

    return $false
}

function Reset-WiFiAdapter {
    param([string]$AdapterName, [int]$OffDuration)

    Write-Log "Resetting WiFi adapter: $AdapterName"

    try {
        # Disable WiFi
        Write-Log "Disabling WiFi..."
        Disable-NetAdapter -Name $AdapterName -Confirm:$false -ErrorAction Stop

        # Wait
        Write-Log "Waiting $OffDuration seconds..."
        Start-Sleep -Seconds $OffDuration

        # Enable WiFi
        Write-Log "Enabling WiFi..."
        Enable-NetAdapter -Name $AdapterName -Confirm:$false -ErrorAction Stop

        # Wait for connection to establish
        Write-Log "Waiting for WiFi to reconnect..."
        Start-Sleep -Seconds 10

        Write-Log "WiFi reset complete"
        return $true
    } catch {
        Write-Log "ERROR resetting WiFi: $_"

        # Try alternative method using netsh
        try {
            Write-Log "Trying alternative reset method..."
            netsh interface set interface $AdapterName disabled
            Start-Sleep -Seconds $OffDuration
            netsh interface set interface $AdapterName enabled
            Start-Sleep -Seconds 10
            Write-Log "WiFi reset complete (netsh method)"
            return $true
        } catch {
            Write-Log "ERROR with netsh method: $_"
            return $false
        }
    }
}

function Test-WifiConnected {
    param([string]$AdapterName)

    try {
        $adapter = Get-NetAdapter -Name $AdapterName -ErrorAction SilentlyContinue
        return ($adapter.Status -eq "Up")
    } catch {
        return $false
    }
}

# Main monitoring loop
Write-Log "========================================="
Write-Log "TeamViewer Monitor Started"
Write-Log "Check Interval: $CheckIntervalSeconds seconds"
Write-Log "Failures before reset: $FailuresBeforeReset"
Write-Log "Max consecutive resets: $MaxConsecutiveResets"
Write-Log "WiFi Adapter: $WifiAdapterName"
Write-Log "Allowed Networks: $($AllowedNetworks -join ', ')"
Write-Log "========================================="

# Check if running as admin (required for adapter control)
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Log "WARNING: Not running as Administrator. WiFi reset may fail."
    Write-Log "Please run PowerShell as Administrator for full functionality."
}

while ($true) {
    try {
        # Check if on an allowed network
        if (-not (Test-AllowedNetwork)) {
            $currentSSID = Get-CurrentSSID
            if ($currentSSID) {
                # Connected to WiFi but not an allowed network - pause monitoring
                Write-Log "Not on allowed network ('$currentSSID'). Pausing monitor..."
                while (-not (Test-AllowedNetwork)) {
                    Start-Sleep -Seconds 60
                }
                Write-Log "Now on allowed network ('$(Get-CurrentSSID)'). Resuming monitor..."
                $ConsecutiveFailures = 0
                $ConsecutiveResets = 0
            } else {
                # No WiFi connection at all
                Start-Sleep -Seconds $CheckIntervalSeconds
                continue
            }
        }

        # Check WiFi is connected first
        if (-not (Test-WifiConnected -AdapterName $WifiAdapterName)) {
            Write-Log "WiFi not connected, waiting..."
            $ConsecutiveFailures = 0
            Start-Sleep -Seconds $CheckIntervalSeconds
            continue
        }

        # Check if we've hit max resets (prevent infinite loop)
        if ($ConsecutiveResets -ge $MaxConsecutiveResets) {
            Write-Log "Max resets ($MaxConsecutiveResets) reached. Pausing for 10 minutes..."
            Start-Sleep -Seconds 600
            $ConsecutiveResets = 0
            Write-Log "Resuming monitoring after cooldown"
        }

        # Test TeamViewer connectivity
        $isConnected = Test-TeamViewerConnectivity

        if ($isConnected) {
            if ($ConsecutiveFailures -gt 0) {
                Write-Log "Connection restored after $ConsecutiveFailures failures"
            }
            $ConsecutiveFailures = 0
            $ConsecutiveResets = 0
        } else {
            $ConsecutiveFailures++
            Write-Log "Connection check failed ($ConsecutiveFailures/$FailuresBeforeReset)"

            if ($ConsecutiveFailures -ge $FailuresBeforeReset) {
                Write-Log "Threshold reached - initiating WiFi reset"

                $resetSuccess = Reset-WiFiAdapter -AdapterName $WifiAdapterName -OffDuration $WifiOffDurationSeconds

                if ($resetSuccess) {
                    Write-Log "WiFi reset completed, waiting for TeamViewer to reconnect..."
                    $ConsecutiveResets++
                    Start-Sleep -Seconds 15
                }

                $ConsecutiveFailures = 0
            }
        }
    } catch {
        Write-Log "ERROR in main loop: $_"
    }

    Start-Sleep -Seconds $CheckIntervalSeconds
}
