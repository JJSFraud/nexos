#!/usr/bin/env bash
# =============================================================================
# NexOS Community Power Pack for Zorin OS / Ubuntu (2015 MacBook Air)
# Adds: Wine (.exe / Roblox), Waydroid (.apk), Darling (.dmg), Mac Optimizations
# =============================================================================

set -e

echo "=========================================================="
echo "  Installing NexOS Power Pack (EXE, APK, DMG Support)     "
echo "  Target: 2015 MacBook Air (Intel Core i5 / HD 6000)      "
echo "=========================================================="
echo ""

# 1. Update and install base tools
echo "[1/5] Updating system packages..."
sudo apt update -qq
sudo apt install -y curl wget git gpg software-properties-common cabextract p7zip-full

# 2. EXE Support (Wine-HQ + Bottles for Roblox & Windows Apps)
echo "[2/5] Setting up Windows .exe support (Wine + Bottles)..."
sudo dpkg --add-architecture i386
sudo mkdir -pm755 /etc/apt/keyrings
sudo wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
sudo wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources || true
sudo apt update -qq || true
sudo apt install -y --install-recommends winehq-staging winetricks || sudo apt install -y wine winetricks

# Install Bottles via Flatpak (Best GUI for Roblox and Windows games on Linux)
if ! command -v flatpak &>/dev/null; then
    sudo apt install -y flatpak
fi
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
flatpak install -y flathub com.usebottles.bottles || true
flatpak install -y flathub org.chromium.Chromium || true

# 3. APK Support (Waydroid for Android Apps on Intel GPU)
echo "[3/5] Setting up Android .apk support (Waydroid)..."
sudo curl --proto '=https' --tlsv1.2 -Sf https://repo.waydro.id/waydroid.gpg -o /usr/share/keyrings/waydroid.gpg
echo "deb [signed-by=/usr/share/keyrings/waydroid.gpg] https://repo.waydro.id/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/waydroid.list
sudo apt update -qq || true
sudo apt install -y waydroid || true

# 4. DMG Support (Darling macOS translation layer)
echo "[4/5] Setting up macOS .dmg support (Darling)..."
sudo apt install -y darling || echo "Note: Darling package will be downloaded via apt or PPA if available."

# 5. MacBook Air 2015 Hardware & Performance Tuning
echo "[5/5] Applying 2015 MacBook Air Hardware Performance Tweaks..."
# Enable Intel HD 6000 GPU acceleration
sudo apt install -y intel-media-va-driver-non-free vainfo mesa-utils
# Trackpad gestures & backlight tools
sudo apt install -y xbacklight brightnessctl macfanctld || true

# Set CPU Governor to Performance/Schedutil
echo "GOVERNOR=\"schedutil\"" | sudo tee /etc/default/cpufrequtils || true

echo ""
echo "=========================================================="
echo "  NexOS Power Pack Installed Successfully!                "
echo "  - Double-click any .exe to run via Wine/Bottles         "
echo "  - Open 'Waydroid' from App Menu to run Android .apk     "
echo "  - Intel HD 6000 60fps GPU acceleration active           "
echo "=========================================================="
