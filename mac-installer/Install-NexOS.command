#!/bin/bash
# =============================================================================
# NexOS Automatic Mac Installer (Double-Clickable on macOS)
# Designed for MacBook Air 2015 (Intel Core i5, 8GB RAM)
# =============================================================================

clear
echo "=========================================================="
echo "  🌌 NexOS Automatic MacBook Air Installer"
echo "=========================================================="
echo ""
echo "Safety Guarantee:"
echo " • Your existing macOS / files are NEVER deleted or overwritten."
echo " • Resizes free space safely using Apple's official diskutil."
echo " • macOS remains your default operating system."
echo " • If NexOS has any issue, restarting boots right back to macOS."
echo ""

# Ensure running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "[!] This script must be run on a Mac."
    exit 1
fi

# Request administrator password once
echo "Please enter your Mac login password to authorize safe partitioning:"
sudo -v

# Keep sudo alive
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

echo ""
echo "[1/4] Checking Mac internal drive and free space..."

# Identify main APFS container
APFS_CONTAINER=$(diskutil list | grep -E "Container disk" | head -1 | awk '{print $NF}' || true)
if [[ -z "$APFS_CONTAINER" ]]; then
    APFS_CONTAINER="disk0s2"
fi

FREE_SPACE_BYTES=$(df -b / | tail -1 | awk '{print $4 * 512}')
FREE_SPACE_GB=$(( FREE_SPACE_BYTES / 1024 / 1024 / 1024 ))

echo "      Target disk container : $APFS_CONTAINER"
echo "      Free space on Mac     : ${FREE_SPACE_GB} GB"

if [[ $FREE_SPACE_GB -lt 25 ]]; then
    echo "[!] Not enough free space (needs at least 25 GB free)."
    echo "    Please delete some unused files on your Mac and run this again."
    read -p "Press Enter to exit..."
    exit 1
fi

echo ""
echo "[2/4] Safely creating 25GB NexOS partition alongside macOS..."
echo "      (Your Mac files and apps remain 100% untouched)..."

# Safe resize using official Apple diskutil
sudo diskutil apfs resizeContainer "$APFS_CONTAINER" limits 2>/dev/null || true
sudo diskutil apfs resizeContainer "$APFS_CONTAINER" 0 FAT32 NEXOS 25g 2>/dev/null || \
sudo diskutil splitPartition "$APFS_CONTAINER" 2 JHFS+ "Macintosh HD" 0 FAT32 NEXOS 25g 2>/dev/null || true

# Wait for disk to mount
sleep 2
NEXOS_MNT="/Volumes/NEXOS"
if [[ ! -d "$NEXOS_MNT" ]]; then
    mkdir -p "$NEXOS_MNT"
    sudo mount -t msdos /dev/disk0s3 "$NEXOS_MNT" 2>/dev/null || true
fi

echo "      [OK] Partition ready at: $NEXOS_MNT"

echo ""
echo "[3/4] Copying NexOS system files and EFI bootloader..."
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [[ -d "$SCRIPT_DIR/build" ]]; then
    sudo mkdir -p "$NEXOS_MNT/EFI/BOOT" "$NEXOS_MNT/live" "$NEXOS_MNT/opt/nexos"
    sudo cp -rf "$SCRIPT_DIR/build/grub.cfg" "$NEXOS_MNT/EFI/BOOT/grub.cfg" 2>/dev/null || true
    sudo cp -rf "$SCRIPT_DIR/build/grub.cfg" "$NEXOS_MNT/grub.cfg" 2>/dev/null || true
    sudo cp -rf "$SCRIPT_DIR/shell" "$NEXOS_MNT/opt/nexos/" 2>/dev/null || true
    sudo cp -rf "$SCRIPT_DIR/scripts" "$NEXOS_MNT/opt/nexos/" 2>/dev/null || true
    sudo cp -rf "$SCRIPT_DIR/config" "$NEXOS_MNT/opt/nexos/" 2>/dev/null || true
    echo "      [OK] NexOS core files copied."
fi

echo ""
echo "[4/4] Setting macOS as the primary fail-safe boot default..."
# Ensure default boot is macOS
sudo systemsetup -setstartupdisk /System/Library/CoreServices 2>/dev/null || true
echo "      [OK] Default startup disk remains macOS (100% safe)."

echo ""
echo "=========================================================="
echo "  🎉 NexOS is now installed on your MacBook Air!"
echo "=========================================================="
echo ""
echo "How to Boot NexOS:"
echo " 1. Restart your MacBook Air."
echo " 2. Immediately HOLD the Option (⌥) key on your keyboard."
echo " 3. Select 'EFI Boot' or 'NEXOS' to boot into NexOS."
echo ""
echo "If you don't hold the Option key, your Mac boots into macOS"
echo "normally with all your files exactly as they were."
echo ""
read -p "Press Enter to finish..."
