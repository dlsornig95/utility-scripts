# Utility Scripts

A collection of utility scripts and tools for Windows.

## TeamViewer Monitor

Monitors TeamViewer connection status and automatically resets WiFi if the connection drops.

### Files
- `teamviewer-monitor.ps1` - Main PowerShell monitoring script
- `start-teamviewer-monitor.bat` - Manual launcher (run as Admin)
- `install-teamviewer-monitor.bat` - Install as auto-start scheduled task

### Features
- Pings TeamViewer master servers to check connectivity
- Monitors TeamViewer log file activity
- Automatically toggles WiFi off/on after consecutive failures
- Logs all activity to `teamviewer-monitor.log`

### Usage

**Manual start:**
```
Right-click start-teamviewer-monitor.bat → Run as Administrator
```

**Auto-start on login:**
```
Right-click install-teamviewer-monitor.bat → Run as Administrator
```

### Configuration

Edit `teamviewer-monitor.ps1` or pass parameters:

| Parameter | Default | Description |
|-----------|---------|-------------|
| CheckIntervalSeconds | 30 | How often to check connectivity |
| FailuresBeforeReset | 3 | Consecutive failures before WiFi reset |
| WifiOffDurationSeconds | 5 | How long WiFi stays off during reset |
| WifiAdapterName | "Wi-Fi" | Name of WiFi adapter |
