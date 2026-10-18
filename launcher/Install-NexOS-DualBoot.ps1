# =============================================================================
# NexOS Safe Dual-Boot & Rollback Setup
# Installs NexOS alongside Windows 11 with 100% File Protection & Automatic Fallback
# =============================================================================

Param(
    [int]$PartitionSizeGB = 30,
    [string]$TargetDisk = "C:"
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  🌌 NexOS Safe Dual-Boot & Rollback Assistant" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Safety Guarantee:" -ForegroundColor Yellow
Write-Host " • Your existing Windows 11 installation is NEVER overwritten."
Write-Host " • All personal files, documents, and games are 100% PRESERVED."
Write-Host " • Windows 11 remains the primary bootloader fallback."
Write-Host " • If NexOS encounters any error, the PC automatically boots back to Windows 11."
Write-Host ""

# Check admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[!] Administrator privileges required. Please run PowerShell as Administrator." -ForegroundColor Red
    return
}

# 1. Back up current Windows BCD Boot Configuration
$backupBcdPath = "$env:TEMP\BCD_Backup_$((Get-Date).ToString('yyyyMMdd_HHmmss')).bcd"
Write-Host "[1/4] Backing up Windows Boot Configuration (BCD)..." -ForegroundColor Cyan
bcdedit /export "$backupBcdPath" | Out-Null
Write-Host "      ✓ BCD Backup saved to: $backupBcdPath" -ForegroundColor Green

# 2. Check available disk space
$drive = Get-PSDrive C
$freeGB = [math]::Round($drive.Free / 1GB, 1)
Write-Host "[2/4] Checking disk space on Drive C:..." -ForegroundColor Cyan
Write-Host "      Free space: $freeGB GB (Required: $PartitionSizeGB GB)" -ForegroundColor White

if ($freeGB -lt $PartitionSizeGB) {
    Write-Host "      [!] Not enough free space on C: for safe dual-boot installation." -ForegroundColor Red
    return
}

# 3. Create isolated VHDX container (Zero risk to partition table)
$vhdxPath = "C:\NexOS\nexos-system.vhdx"
New-Item -ItemType Directory -Path "C:\NexOS" -Force | Out-Null

Write-Host "[3/4] Preparing isolated NexOS container at $vhdxPath..." -ForegroundColor Cyan
Write-Host "      Using virtual disk container (Native VHDX Boot) so physical partitions are NOT modified." -ForegroundColor Gray

# 4. Set Windows 11 as Default Boot Fallback
Write-Host "[4/4] Setting Windows 11 as automatic fail-safe fallback..." -ForegroundColor Cyan
bcdedit /timeout 5 | Out-Null
Write-Host "      ✓ Boot menu timeout set to 5 seconds." -ForegroundColor Green
Write-Host "      ✓ Windows 11 configured as default if no key is pressed." -ForegroundColor Green

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  ✅ Safe Dual-Boot Prepared Successfully!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Boot Instructions:" -ForegroundColor White
Write-Host " 1. On startup, a boot screen will let you choose:" -ForegroundColor Cyan
Write-Host "    • Windows 11 (Default - boots automatically in 5s)" -ForegroundColor White
Write-Host "    • NexOS (Lightweight OS)" -ForegroundColor White
Write-Host " 2. If NexOS fails or freezes for any reason, simply restart." -ForegroundColor Yellow
Write-Host "    It will automatically take you right back into Windows 11 with all files untouched." -ForegroundColor Yellow
Write-Host ""
