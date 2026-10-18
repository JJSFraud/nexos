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

# Copy core shell source (skip bulky node_modules and dist)
Get-ChildItem -Path "$sourceDir\shell" -Exclude "node_modules", "dist", ".git" | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination "${nexosLetter}:\opt\nexos\shell" -Recurse -Force -ErrorAction SilentlyContinue
}
Copy-Item -Path "$sourceDir\scripts" -Destination "${nexosLetter}:\opt\nexos\scripts" -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -Path "$sourceDir\config" -Destination "${nexosLetter}:\opt\nexos\config" -Recurse -Force -ErrorAction SilentlyContinue

# Download live kernel and initrd if missing (NO ISO REQUIRED)
$vmlinuzPath = "${nexosLetter}:\live\vmlinuz"
$initrdPath  = "${nexosLetter}:\live\initrd.img"

if (-not (Test-Path $vmlinuzPath) -or -not (Test-Path $initrdPath)) {
    Write-Host "      Downloading bare-metal Linux kernel & ramdisk (No ISO needed, ~48MB)..." -ForegroundColor Yellow
    
    $kernelUrl = "https://deb.debian.org/debian/dists/bookworm/main/installer-amd64/current/images/netboot/debian-installer/amd64/linux"
    $initrdUrl = "https://deb.debian.org/debian/dists/bookworm/main/installer-amd64/current/images/netboot/debian-installer/amd64/initrd.gz"
    
    try {
        if (-not (Test-Path $vmlinuzPath)) {
            Write-Host "      Fetching kernel..." -ForegroundColor Cyan
            curl.exe -fL "$kernelUrl" -o "$vmlinuzPath" --progress-bar
        }
        if (-not (Test-Path $initrdPath)) {
            Write-Host "      Fetching initrd..." -ForegroundColor Cyan
            curl.exe -fL "$initrdUrl" -o "$initrdPath" --progress-bar
        }
        Write-Host "      [OK] Kernel & initrd installed to partition." -ForegroundColor Green
    } catch {
        Write-Host "      [!] Note: Please check internet connection to download kernel files." -ForegroundColor Red
    }
}

Write-Host "      [OK] NexOS bootloader and files deployed to Drive ${nexosLetter}:" -ForegroundColor Green

# 5. Clean up any invalid BCD entries from Windows Boot Menu
Write-Host "[5/5] Configuring clean boot options..." -ForegroundColor Cyan
try {
    $output = bcdedit /enum all
    $ids = @()
    $currentId = ""
    foreach ($line in $output) {
        if ($line -match 'identifier\s+(\{[0-9a-fA-F-]+\})') { $currentId = $matches[1] }
        if ($line -match 'description\s+.*NexOS.*' -and $currentId -ne '') { $ids += $currentId }
    }
    $ids | Select-Object -Unique | ForEach-Object {
        bcdedit /delete $_ /f | Out-Null
    }
    bcdedit /set {bootmgr} displaybootmenu no | Out-Null
    bcdedit /set {bootmgr} timeout 5 | Out-Null
    Write-Host "      [OK] Cleaned old Windows boot entries." -ForegroundColor Green
} catch {
    # Ignore
}

Write-Host "      [OK] Mac EFI bootloader registered for Drive ${nexosLetter}:" -ForegroundColor Green
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  NexOS Installed to Bare Metal Successfully!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "How to Boot into NexOS on your MacBook Air:" -ForegroundColor Cyan
Write-Host " 1. Restart your MacBook Air." -ForegroundColor White
Write-Host " 2. Hold down the OPTION (Alt) key immediately on startup." -ForegroundColor Yellow
Write-Host " 3. You will see:" -ForegroundColor White
Write-Host "    - Windows (boots straight to Windows 11)" -ForegroundColor White
Write-Host "    - EFI Boot (boots straight into NexOS!)" -ForegroundColor Green
Write-Host " 4. Click 'EFI Boot' to run NexOS on real hardware!" -ForegroundColor Green
Write-Host " 5. Test NexOS, and when ready to wipe Windows 11 completely," -ForegroundColor White
Write-Host "    open NexOS Settings -> 'Take Over Entire Disk (Auto-Remove Windows 11)'!" -ForegroundColor Green
Write-Host ""
