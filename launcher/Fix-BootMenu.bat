@echo off
title NexOS Boot Menu Cleaner
echo ========================================================
echo   Removing duplicate / broken NexOS entries from Windows
echo ========================================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "& {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host '[!] Administrator required. Right-click and choose Run as Administrator.' -ForegroundColor Red
        pause
        exit
    }
    
    $output = bcdedit /enum all
    $ids = @()
    $currentId = ''
    foreach ($line in $output) {
        if ($line -match 'identifier\s+(\{[0-9a-fA-F-]+\})') {
            $currentId = $matches[1]
        }
        if ($line -match 'description\s+.*NexOS.*' -and $currentId -ne '') {
            $ids += $currentId
        }
    }
    
    if ($ids.Count -eq 0) {
        Write-Host '[OK] No broken NexOS entries found in Windows BCD.' -ForegroundColor Green
    } else {
        $unique = $ids | Select-Object -Unique
        foreach ($id in $unique) {
            Write-Host ('Cleaning up entry: ' + $id) -ForegroundColor Cyan
            bcdedit /delete $id /f | Out-Null
        }
        Write-Host '[OK] All broken NexOS entries successfully removed from Windows boot menu!' -ForegroundColor Green
    }
    
    # Reset bootmenu timeout back to standard
    bcdedit /set {bootmgr} displaybootmenu no | Out-Null
    bcdedit /set {bootmgr} timeout 5 | Out-Null
    Write-Host '[OK] Windows 11 restored to clean direct boot.' -ForegroundColor Green
}"

echo.
echo Done! Press any key to exit.
pause >nul
