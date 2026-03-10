@echo off
:: Install TeamViewer Monitor as a Scheduled Task
:: Must be run as Administrator

echo Installing TeamViewer Monitor as a scheduled task...
echo.

:: Create scheduled task to run at logon
schtasks /create /tn "TeamViewerMonitor" /tr "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File %USERPROFILE%\.local\bin\teamviewer-monitor.ps1" /sc onlogon /rl highest /f

if %errorlevel% equ 0 (
    echo.
    echo SUCCESS: TeamViewer Monitor installed!
    echo It will start automatically when you log in.
    echo.
    echo To start it now, run: start-teamviewer-monitor.bat
    echo To uninstall, run: schtasks /delete /tn "TeamViewerMonitor" /f
) else (
    echo.
    echo ERROR: Failed to create scheduled task.
    echo Make sure you're running this as Administrator.
)

echo.
pause
