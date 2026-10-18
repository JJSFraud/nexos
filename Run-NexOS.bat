@echo off
title NexOS (No ISO / No VM)
cd /d "%~dp0"

echo ========================================================
echo   Starting NexOS (Windows 12 + macOS Hybrid Shell)
echo   PIN Passcode: 1234
echo   Antivirus & Defender + Gaming Mode Enabled
echo ========================================================
echo.

if exist "NexOS.exe" (
    echo Starting NexOS Standalone...
    start "" "NexOS.exe"
    exit /b 0
)

if exist "dist\win-unpacked\NexOS Shell.exe" (
    echo Starting NexOS Shell...
    start "" "dist\win-unpacked\NexOS Shell.exe"
    exit /b 0
)

echo Starting NexOS runtime...
cd shell
where node >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo Installing portable runtime...
    powershell -Command "winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements"
)

if not exist node_modules (
    call npm install
)

call npm start
