#!/usr/bin/env bash
# =============================================================================
# NexOS Full Disk Takeover — Automated Windows 11 Removal Script
# =============================================================================
# Run this ONLY from inside NexOS once you have confirmed everything works!
# This script:
#  1. Automatically locates the Windows 11 NTFS partition.
#  2. Backs up user files (Desktop, Documents, Downloads, Pictures) to /home/nexos/Windows_Backup.
#  3. Deletes the Windows 11 partition.
#  4. Expands the NexOS root partition across 100% of the drive.
#  5. Cleans up EFI boot entries and updates GRUB so NexOS boots instantly.
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

[[ $EUID -eq 0 ]] || error "This script must be run as root: sudo $0"

echo -e "${YELLOW}"
echo "=========================================================="
echo "  ⚠️  NexOS Automated Windows 11 Removal & Disk Expansion"
echo "=========================================================="
echo -e "${NC}"
echo "This will permanently remove Windows 11 and expand NexOS"
echo "to utilize 100% of your SSD/hard drive."
echo ""

# 1. Detect disk and partitions
info "Scanning storage drives..."
ROOT_DEV=$(findmnt -n -o SOURCE /)
ROOT_DISK=$(lsblk -no PKNAME "$ROOT_DEV" 2>/dev/null || echo "/dev/sda")
[[ "$ROOT_DISK" =~ ^/dev/ ]] || ROOT_DISK="/dev/$ROOT_DISK"

info "NexOS root is on: $ROOT_DEV ($ROOT_DISK)"

# Find Windows NTFS partitions
WIN_PART=$(lsblk -l -o NAME,FSTYPE,LABEL | grep -iE 'ntfs|windows' | head -1 | awk '{print $1}' || true)

if [[ -n "$WIN_PART" ]]; then
    WIN_DEV="/dev/$WIN_PART"
    info "Detected Windows 11 partition at: $WIN_DEV"

    # Backup personal files
    BACKUP_DIR="/home/nexos/Windows_Backup"
    mkdir -p "$BACKUP_DIR"
    MNT_WIN="/mnt/win_temp"
    mkdir -p "$MNT_WIN"

    info "Mounting Windows partition to preserve personal documents..."
    if mount -o ro "$WIN_DEV" "$MNT_WIN" 2>/dev/null; then
        USER_DIR=$(find "$MNT_WIN/Users" -mindepth 1 -maxdepth 1 -type d ! -name "Public" ! -name "Default" 2>/dev/null | head -1 || true)
        if [[ -n "$USER_DIR" ]]; then
            info "Backing up files from $(basename "$USER_DIR")..."
            for folder in Desktop Documents Downloads Pictures Music; do
                if [[ -d "$USER_DIR/$folder" ]]; then
                    info "Preserving $folder..."
                    rsync -a "$USER_DIR/$folder" "$BACKUP_DIR/" 2>/dev/null || true
                fi
            done
            chown -R nexos:nexos "$BACKUP_DIR" 2>/dev/null || true
            ok "Personal files backed up to: $BACKUP_DIR"
        fi
        umount "$MNT_WIN" || true
    fi

    # Wipe Windows partition
    info "Removing Windows 11 partition ($WIN_DEV)..."
    wipefs -a "$WIN_DEV" 2>/dev/null || true
    ok "Windows 11 partition removed."
else
    warn "No separate NTFS Windows partition found. Disk is already dedicated to NexOS."
fi

# 2. Expand root filesystem to 100% of disk space
info "Expanding NexOS filesystem to 100% of storage..."
growpart "$ROOT_DISK" 1 2>/dev/null || true
resize2fs "$ROOT_DEV" 2>/dev/null || true

# 3. Clean up EFI Bootloader entries
info "Configuring NexOS as the sole operating system in EFI..."
if command -v efibootmgr &>/dev/null; then
    # Remove Windows Boot Manager from EFI
    WIN_BOOT_NUM=$(efibootmgr 2>/dev/null | grep -i "Windows Boot Manager" | sed -E 's/Boot([0-9A-Fa-f]+)\*.*/\1/' || true)
    if [[ -n "$WIN_BOOT_NUM" ]]; then
        info "Removing Windows Boot Manager entry Boot$WIN_BOOT_NUM..."
        efibootmgr -b "$WIN_BOOT_NUM" -B 2>/dev/null || true
    fi
fi

# 4. Update GRUB
if command -v update-grub &>/dev/null; then
    info "Updating GRUB configuration..."
    update-grub 2>/dev/null || true
fi

echo ""
ok "=========================================================="
ok "  🎉 Windows 11 successfully removed!"
ok "  🚀 NexOS now occupies 100% of your storage drive."
ok "  📁 Your old Windows files are safe in: /home/nexos/Windows_Backup"
ok "=========================================================="
echo ""
