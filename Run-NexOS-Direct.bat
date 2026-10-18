@echo off
title NexOS Desktop Shell Launcher (No ISO / No VM)
cd /d "%~dp0\shell"

echo ========================================================
echo   Starting NexOS Desktop Shell...
echo   (Windows 12 UI + PIN 1234 + Antivirus + Gaming Mode)
echo ========================================================
echo.

where node >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [!] Node.js not detected. Installing portable runtime...
    powershell -Command "winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements"
)

if not exist node_modules (
    echo [*] Setting up dependencies (first time only)...
    call npm install
)

echo [*] Launching NexOS Desktop Shell...
call npm start
pause
