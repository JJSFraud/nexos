#!/usr/bin/env bash
# =============================================================================
# NexOS — Build Dependency Installer
# Run on an Ubuntu 22.04+ or Debian bookworm host (or WSL2).
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

[[ $EUID -eq 0 ]] || error "Please run as root: sudo $0"

info "Updating package lists..."
apt-get update -qq

info "Installing core ISO build tools..."
apt-get install -y --no-install-recommends \
    debootstrap \
    squashfs-tools \
    xorriso \
    grub-pc-bin \
    grub-efi-amd64-bin \
    grub-common \
    grub2-common \
    mtools \
    dosfstools \
    genisoimage \
    isolinux \
    syslinux-utils \
    live-build \
    live-boot \
    live-config \
    || true

info "Installing additional utilities..."
apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    rsync \
    pv \
    file \
    gnupg \
    ca-certificates \
    apt-transport-https \
    || true

info "Installing Node.js (for shell pre-build)..."
if ! command -v node &>/dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
else
    warn "Node.js already installed: $(node --version)"
fi

info "Verifying tools..."
REQUIRED_TOOLS=(debootstrap mksquashfs xorriso grub-mkrescue)
ALL_OK=true
for tool in "${REQUIRED_TOOLS[@]}"; do
    if command -v "$tool" &>/dev/null; then
        ok "$tool ✓"
    else
        warn "$tool not found after install — may need manual intervention."
        ALL_OK=false
    fi
done

if $ALL_OK; then
    ok "All build dependencies installed successfully!"
else
    warn "Some tools may be missing. Check the output above."
fi

info "Build environment ready. You can now run: sudo bash build/build-iso.sh"
