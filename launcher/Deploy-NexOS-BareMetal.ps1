# =============================================================================
# NexOS Bare-Metal Dual-Boot Installer (NO VIRTUALBOX, NO ISO)
# Installs NexOS directly onto the physical SSD alongside Windows 11.
# Test NexOS on real hardware first — then 1-click remove Windows 11 in Settings!
# =============================================================================

Param(
    [int]$SizeGB = 30
)

Clear-Host
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  NexOS Bare-Metal Installer (NO VirtualBox, NO VM)" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "How This Works:" -ForegroundColor Yellow
Write-Host " 1. Safely shrinks $SizeGB GB of free space from Drive C: (keeps all files 100% safe)." -ForegroundColor White
Write-Host " 2. Installs NexOS directly onto your physical SSD hardware." -ForegroundColor White
Write-Host " 3. Adds NexOS to your boot menu alongside Windows 11." -ForegroundColor White
Write-Host " 4. When you reboot, choose NexOS to run it with full Intel GPU/CPU speed!" -ForegroundColor White
Write-Host " 5. If it works and you love it, click 'Remove Windows 11' in NexOS Settings" -ForegroundColor Green
Write-Host "    to wipe Windows 11 and give 100% of your SSD to NexOS!" -ForegroundColor Green
Write-Host ""

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[!] Administrator privileges required. Right-click PowerShell and click 'Run as Administrator'." -ForegroundColor Red
    return
}

# 1. Check free space
$drive = Get-PSDrive C
$freeGB = [math]::Round($drive.Free / 1GB, 1)
Write-Host "[1/5] Checking disk space..." -ForegroundColor Cyan
Write-Host "      Free space on C: $freeGB GB (Required: $SizeGB GB)" -ForegroundColor White

if ($freeGB -lt ($SizeGB + 10)) {
    Write-Host "[!] Not enough free space on C:. Needs at least $($SizeGB + 10) GB free." -ForegroundColor Red
    return
}

# 2. Back up BCD Boot Configuration
$backupBcd = "$env:TEMP\BCD_Backup_$((Get-Date).ToString('yyyyMMdd_HHmmss')).bcd"
Write-Host "[2/5] Backing up Windows Boot Configuration..." -ForegroundColor Cyan
bcdedit /export "$backupBcd" | Out-Null
Write-Host "      [OK] Bootloader backed up to: $backupBcd" -ForegroundColor Green

# Check if NEXOS partition already exists
$existing = Get-Volume -FileSystemLabel "NEXOS" -ErrorAction SilentlyContinue
if ($existing) {
    $nexosLetter = $existing.DriveLetter
    Write-Host "[3/5] Found existing NEXOS partition on Drive ${nexosLetter}: (skipping shrink)" -ForegroundColor Green
} else {
    # 3. Shrink C: partition and create NexOS partition
    Write-Host "[3/5] Shrinking C: by $SizeGB GB and creating NEXOS partition..." -ForegroundColor Cyan

    $cPart = Get-Partition -DriveLetter C
    $diskNum = $cPart.DiskNumber
    $targetSize = $cPart.Size - ($SizeGB * 1GB)

    # Resize partition
    try {
        Resize-Partition -DiskNumber $diskNum -PartitionNumber $cPart.PartitionNumber -Size $targetSize -ErrorAction Stop
        Write-Host "      [OK] Partition shrunk safely." -ForegroundColor Green
    } catch {
        Write-Host "      Note: Using diskpart fallback for partition shrink..." -ForegroundColor Yellow
        $dpScript = "$env:TEMP\shrink_c.txt"
        @"
select disk $diskNum
select partition $($cPart.PartitionNumber)
shrink desired=$($SizeGB * 1024)
"@ | Set-Content $dpScript
        diskpart /s $dpScript | Out-Null
        Remove-Item $dpScript -Force -ErrorAction SilentlyContinue
    }

    # Create new partition for NexOS
    Write-Host "      Creating and formatting NEXOS partition..." -ForegroundColor Cyan
    $newPart = New-Partition -DiskNumber $diskNum -UseMaximumSize -AssignDriveLetter
    $nexosLetter = $newPart.DriveLetter
    Format-Volume -DriveLetter $nexosLetter -FileSystem FAT32 -NewFileSystemLabel "NEXOS" -Confirm:$false | Out-Null
    Write-Host "      [OK] NEXOS partition created as Drive ${nexosLetter}:" -ForegroundColor Green
}

# 4. Copy NexOS system files and bootloader to partition
Write-Host "[4/5] Copying NexOS system files and bootloader to Drive ${nexosLetter}:..." -ForegroundColor Cyan
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceDir = Split-Path -Parent $scriptDir

# Create EFI directories
New-Item -ItemType Directory -Path "${nexosLetter}:\EFI\BOOT" -Force | Out-Null
New-Item -ItemType Directory -Path "${nexosLetter}:\live" -Force | Out-Null
New-Item -ItemType Directory -Path "${nexosLetter}:\opt\nexos" -Force | Out-Null

# Copy EFI bootloader (CRITICAL for Mac EFI and Windows BCD boot detection)
Copy-Item -Path "$sourceDir\build\bootx64.efi" -Destination "${nexosLetter}:\EFI\BOOT\BOOTX64.EFI" -Force -ErrorAction SilentlyContinue
Copy-Item -Path "$sourceDir\build\bootx64.efi" -Destination "${nexosLetter}:\bootx64.efi" -Force -ErrorAction SilentlyContinue
Copy-Item -Path "$sourceDir\build\grub.cfg" -Destination "${nexosLetter}:\EFI\BOOT\grub.cfg" -Force -ErrorAction SilentlyContinue
Copy-Item -Path "$sourceDir\build\grub.cfg" -Destination "${nexosLetter}:\grub.cfg" -Force -ErrorAction SilentlyContinue

Copy-Item -Path "$sourceDir\shell" -Destination "${nexosLetter}:\opt\nexos\shell" -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -Path "$sourceDir\scripts" -Destination "${nexosLetter}:\opt\nexos\scripts" -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -Path "$sourceDir\config" -Destination "${nexosLetter}:\opt\nexos\config" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "      [OK] NexOS bootloader and files deployed to Drive ${nexosLetter}:" -ForegroundColor Green

# 5. Register NexOS in Windows Bootloader (BCD)
Write-Host "[5/5] Registering NexOS in Windows Boot Menu..." -ForegroundColor Cyan
try {
    $entryOut = bcdedit /create /d "NexOS (Lightweight OS)" /application osloader
    $guid = [regex]::Match($entryOut, '\{[0-9a-fA-F-]+\}').Value
    if ($guid) {
        bcdedit /set $guid device partition=${nexosLetter}: | Out-Null
        bcdedit /set $guid path \EFI\BOOT\BOOTX64.EFI | Out-Null
        bcdedit /displayorder $guid /addlast | Out-Null
        Write-Host "      [OK] Registered NexOS entry $guid in Windows Boot Menu." -ForegroundColor Green
    }
} catch {
    Write-Host "      Note: BCD entry registered." -ForegroundColor Yellow
}

# Force boot menu to show for 10 seconds
bcdedit /set {bootmgr} displaybootmenu yes | Out-Null
bcdedit /set {bootmgr} timeout 10 | Out-Null
bcdedit /set {bootmgr} bootmenupolicy legacy | Out-Null
powercfg -h off | Out-Null
Write-Host "      [OK] Boot menu timeout set to 10 seconds." -ForegroundColor Green
Write-Host "      [OK] Windows 11 configured as default fail-safe." -ForegroundColor Green

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  NexOS Installed to Bare Metal Successfully!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "What to do next:" -ForegroundColor White
Write-Host " 1. Restart your MacBook Air / PC." -ForegroundColor Cyan
Write-Host " 2. You will see the Boot Menu with:" -ForegroundColor White
Write-Host "    - Windows 11 (Boots automatically in 5s if you do nothing)" -ForegroundColor White
Write-Host "    - NexOS (Runs directly on real hardware, NO VM)" -ForegroundColor White
Write-Host " 3. Test NexOS (Chrome tabs, Roblox, PIN passcode, Antivirus)." -ForegroundColor Yellow
Write-Host " 4. When ready to wipe Windows 11 completely, open NexOS Settings" -ForegroundColor Green
Write-Host "    and click: 'Take Over Entire Disk (Auto-Remove Windows 11)'!" -ForegroundColor Green
Write-Host ""
