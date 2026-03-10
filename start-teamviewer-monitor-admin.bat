@echo off
:: Start TeamViewer Monitor with Administrator privileges
:: This script will request elevation if not already admin

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo Starting TeamViewer Monitor as Administrator...
start /b powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0teamviewer-monitor.ps1"
echo Monitor started in background.
timeout /t 3
