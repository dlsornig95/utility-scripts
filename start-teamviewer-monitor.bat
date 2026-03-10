@echo off
:: TeamViewer Monitor Launcher
:: Run this as Administrator for full functionality

echo Starting TeamViewer Connection Monitor...
echo.
echo This script monitors TeamViewer and resets WiFi if connection drops.
echo Press Ctrl+C to stop.
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0teamviewer-monitor.ps1"

pause
