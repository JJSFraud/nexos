#!/usr/bin/env bash
# =============================================================================
# Installer for Linux Zoner — Intel HD 6000 Gaming & Graphics Optimizer
# =============================================================================

set -e

INSTALL_DIR="$HOME/.local/share/zoner"
BASE_URL="https://raw.githubusercontent.com/JJSFraud/nexos/main/zoner"

echo "=========================================================="
echo "  ⚡ Installing Linux Zoner Graphics & Gaming Engine      "
echo "  Target: 2015 MacBook Air (Intel Core i5 / HD 6000)      "
echo "=========================================================="
echo ""

# 1. Install prerequisites
echo "[1/4] Installing drivers, GameMode, xdotool, and graphics libraries..."
sudo apt update -qq
sudo apt install -y python3 python3-tk gamemode mesa-utils mesa-vulkan-drivers intel-media-va-driver-non-free xdotool curl

# 2. Setup installation directory and download files
echo "[2/4] Downloading Linux Zoner app and phone companion..."
mkdir -p "$INSTALL_DIR"

# If running from a local git clone where files exist, copy them; otherwise download from GitHub
SCRIPT_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"
if [[ -n "$SCRIPT_SOURCE_DIR" && -f "$SCRIPT_SOURCE_DIR/zoner.py" ]]; then
    cp "$SCRIPT_SOURCE_DIR/zoner.py" "$INSTALL_DIR/"
    cp "$SCRIPT_SOURCE_DIR/phone_server.py" "$INSTALL_DIR/"
    cp "$SCRIPT_SOURCE_DIR/zoner-core.sh" "$INSTALL_DIR/"
    cp "$SCRIPT_SOURCE_DIR/launch-game.sh" "$INSTALL_DIR/"
else
    curl -sL "${BASE_URL}/zoner.py" -o "${INSTALL_DIR}/zoner.py"
    curl -sL "${BASE_URL}/phone_server.py" -o "${INSTALL_DIR}/phone_server.py"
    curl -sL "${BASE_URL}/zoner-core.sh" -o "${INSTALL_DIR}/zoner-core.sh"
    curl -sL "${BASE_URL}/launch-game.sh" -o "${INSTALL_DIR}/launch-game.sh"
fi

chmod +x "${INSTALL_DIR}/zoner-core.sh"
chmod +x "${INSTALL_DIR}/launch-game.sh"
chmod +x "${INSTALL_DIR}/zoner.py"

# 3. Configure sudoers rule so Zoner can toggle GPU clock without password popup
echo "[3/4] Configuring low-latency hardware controls..."
SUDOERS_FILE="/etc/sudoers.d/zoner"
echo "%sudo ALL=(ALL) NOPASSWD: ${INSTALL_DIR}/zoner-core.sh" | sudo tee "$SUDOERS_FILE" >/dev/null
sudo chmod 0440 "$SUDOERS_FILE"

# 4. Create Desktop Entry in App Menu
echo "[4/4] Creating Desktop shortcut and App Menu entry..."
mkdir -p ~/.local/share/applications
cat << EOF > ~/.local/share/applications/zoner.desktop
[Desktop Entry]
Name=Linux Zoner
Comment=Intel HD 6000 GPU & Graphics Optimizer
Exec=python3 "${INSTALL_DIR}/zoner.py"
Icon=preferences-system
Terminal=false
Type=Application
Categories=Game;Settings;HardwareSettings;
EOF

# Copy to Desktop if Desktop exists
if [[ -d ~/Desktop ]]; then
    cp ~/.local/share/applications/zoner.desktop ~/Desktop/
    chmod +x ~/Desktop/zoner.desktop 2>/dev/null || true
fi

echo ""
echo "=========================================================="
echo "  ✅ Linux Zoner Installed Successfully!                  "
echo "  - Find 'Linux Zoner' in your App Menu or Desktop        "
echo "  - Launching Linux Zoner now...                          "
echo "=========================================================="

python3 "${INSTALL_DIR}/zoner.py" &
