#!/usr/bin/env bash
# =============================================================================
# Installer for Linux Zoner — Intel HD 6000 Gaming & Graphics Optimizer
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================================="
echo "  ⚡ Installing Linux Zoner Graphics & Gaming Engine      "
echo "  Target: 2015 MacBook Air (Intel Core i5 / HD 6000)      "
echo "=========================================================="
echo ""

# 1. Install prerequisites
echo "[1/4] Installing drivers, GameMode, and graphics libraries..."
sudo apt update -qq
sudo apt install -y python3 python3-tk gamemode mesa-utils mesa-vulkan-drivers intel-media-va-driver-non-free

# 2. Make scripts executable
echo "[2/4] Setting execution permissions..."
chmod +x "${SCRIPT_DIR}/zoner-core.sh"
chmod +x "${SCRIPT_DIR}/launch-game.sh"
chmod +x "${SCRIPT_DIR}/zoner.py"

# 3. Configure sudoers rule so Zoner can toggle GPU clock without password popup
echo "[3/4] Configuring low-latency hardware controls..."
SUDOERS_FILE="/etc/sudoers.d/zoner"
echo "%sudo ALL=(ALL) NOPASSWD: ${SCRIPT_DIR}/zoner-core.sh" | sudo tee "$SUDOERS_FILE" >/dev/null
sudo chmod 0440 "$SUDOERS_FILE"

# 4. Create Desktop Entry in App Menu
echo "[4/4] Creating Desktop shortcut and App Menu entry..."
mkdir -p ~/.local/share/applications
cat << EOF > ~/.local/share/applications/zoner.desktop
[Desktop Entry]
Name=Linux Zoner
Comment=Intel HD 6000 GPU & Graphics Optimizer
Exec=python3 "${SCRIPT_DIR}/zoner.py"
Icon=preferences-system
Terminal=false
Type=Application
Categories=Game;Settings;HardwareSettings;
EOF

# Copy to Desktop if Desktop exists
if [[ -d ~/Desktop ]]; then
    cp ~/.local/share/applications/zoner.desktop ~/Desktop/
    chmod +x ~/Desktop/zoner.desktop
fi

echo ""
echo "=========================================================="
echo "  ✅ Linux Zoner Installed Successfully!                  "
echo "  - Find 'Linux Zoner' in your App Menu or Desktop        "
echo "  - Launching Linux Zoner now...                          "
echo "=========================================================="

python3 "${SCRIPT_DIR}/zoner.py" &
