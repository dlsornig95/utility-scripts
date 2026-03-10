# TeamViewer Connection Monitor
# Monitors TeamViewer connectivity and resets WiFi if connection drops

param(
    [int]$CheckIntervalSeconds = 30,
    [int]$FailuresBeforeReset = 3,
    [int]$WifiOffDurationSeconds = 5,
    [string]$WifiAdapterName = "Wi-Fi",
    [string]$LogFile = "$env:USERPROFILE\.local\bin\teamviewer-monitor.log"
)

# TeamViewer master server endpoints to check connectivity
$TeamViewerServers = @(
    "master1.teamviewer.com",
    "master2.teamviewer.com",
    "master3.teamviewer.com",
    "ping3.teamviewer.com"
)

$TeamViewerLogPath = "C:\Program Files\TeamViewer\TeamViewer15_Logfile.log"
$ConsecutiveFailures = 0
$LastLogPosition = 0

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
Write-Log "WiFi Adapter: $WifiAdapterName"
Write-Log "========================================="

# Check if running as admin (required for adapter control)
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Log "WARNING: Not running as Administrator. WiFi reset may fail."
    Write-Log "Please run PowerShell as Administrator for full functionality."
}

while ($true) {
    try {
        # Check WiFi is connected first
        if (-not (Test-WifiConnected -AdapterName $WifiAdapterName)) {
            Write-Log "WiFi not connected, waiting..."
            $ConsecutiveFailures = 0
            Start-Sleep -Seconds $CheckIntervalSeconds
            continue
        }

        # Test TeamViewer connectivity
        $isConnected = Test-TeamViewerConnectivity

        if ($isConnected) {
            if ($ConsecutiveFailures -gt 0) {
                Write-Log "Connection restored after $ConsecutiveFailures failures"
            } else {
                Write-Log "Connection OK"
            }
            $ConsecutiveFailures = 0
        } else {
            $ConsecutiveFailures++
            Write-Log "Connection check failed ($ConsecutiveFailures/$FailuresBeforeReset)"

            if ($ConsecutiveFailures -ge $FailuresBeforeReset) {
                Write-Log "Threshold reached - initiating WiFi reset"

                $resetSuccess = Reset-WiFiAdapter -AdapterName $WifiAdapterName -OffDuration $WifiOffDurationSeconds

                if ($resetSuccess) {
                    Write-Log "WiFi reset completed, waiting for TeamViewer to reconnect..."
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
