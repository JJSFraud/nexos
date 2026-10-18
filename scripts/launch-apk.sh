#!/usr/bin/env bash
# =============================================================================
# NexOS — Waydroid APK Launcher
# Usage: launch-apk.sh <path-to.apk>
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[Waydroid]${NC} $*"; }
ok()    { echo -e "${GREEN}[Waydroid]${NC} $*"; }
warn()  { echo -e "${YELLOW}[Waydroid]${NC} $*"; }
error() { echo -e "${RED}[Waydroid]${NC} $*"; exit 1; }

# ---------------------------------------------------------------------------
# Argument check
# ---------------------------------------------------------------------------
APK_PATH="${1:-}"
if [[ -z "$APK_PATH" ]]; then
    echo "Usage: $0 <path-to.apk>"
    exit 1
fi

# ---------------------------------------------------------------------------
# Validate APK file
# ---------------------------------------------------------------------------
APK_PATH=$(realpath -e "$APK_PATH" 2>/dev/null) || \
    error "File not found: ${APK_PATH}"

[[ -f "$APK_PATH" ]] || error "Not a regular file: ${APK_PATH}"

EXT="${APK_PATH##*.}"
[[ "${EXT,,}" == "apk" ]] || warn "File does not have .apk extension. Proceeding anyway..."

# Basic APK magic check (ZIP with PK header)
MAGIC=$(xxd -l 2 "$APK_PATH" 2>/dev/null | head -1 | awk '{print $2$3}' || echo "")
if [[ "${MAGIC^^}" != "504B"* ]]; then
    error "File does not appear to be a valid APK/ZIP archive."
fi

info "APK: $(basename "$APK_PATH")"

# ---------------------------------------------------------------------------
# Check Waydroid installation
# ---------------------------------------------------------------------------
if ! command -v waydroid &>/dev/null; then
    error "Waydroid is not installed. Run: sudo apt-get install -y waydroid"
fi

WAYDROID_VERSION=$(waydroid --version 2>/dev/null | head -1 || echo "unknown")
info "Waydroid: ${WAYDROID_VERSION}"

# ---------------------------------------------------------------------------
# Check if Waydroid has been initialised
# ---------------------------------------------------------------------------
WAYDROID_DATA_DIR="${WAYDROID_DATA_DIR:-/var/lib/waydroid}"
if [[ ! -f "${WAYDROID_DATA_DIR}/image/system.img" ]]; then
    warn "Waydroid has not been initialised yet."
    info "Running waydroid init (requires internet connection)..."
    sudo waydroid init 2>/dev/null || \
    sudo waydroid init -s GAPPS 2>/dev/null || \
    error "Waydroid initialisation failed. Run manually: sudo waydroid init"
fi

# ---------------------------------------------------------------------------
# Ensure Waydroid session/container is running
# ---------------------------------------------------------------------------
check_waydroid_running() {
    waydroid status 2>/dev/null | grep -qi "RUNNING" || return 1
}

start_waydroid() {
    info "Starting Waydroid session..."
    waydroid session start &
    WDROID_PID=$!

    info "Waiting for Waydroid to be ready (up to 60s)..."
    for i in $(seq 1 60); do
        if check_waydroid_running; then
            ok "Waydroid is running."
            return 0
        fi
        sleep 1
    done

    error "Waydroid failed to start within 60 seconds."
}

if ! check_waydroid_running; then
    start_waydroid
else
    ok "Waydroid already running."
fi

# ---------------------------------------------------------------------------
# Install the APK
# ---------------------------------------------------------------------------
info "Installing APK: $(basename "$APK_PATH")..."

set +e
waydroid app install "$APK_PATH"
INSTALL_EXIT=$?
set -e

if [[ $INSTALL_EXIT -eq 0 ]]; then
    ok "APK installed successfully."
else
    error "APK installation failed (exit code ${INSTALL_EXIT}). Check that the APK is compatible with Android x86_64."
fi

# ---------------------------------------------------------------------------
# Attempt to launch the newly installed app
# ---------------------------------------------------------------------------
info "Detecting package name from APK..."
if command -v aapt &>/dev/null; then
    PKG_NAME=$(aapt dump badging "$APK_PATH" 2>/dev/null | grep "package: name=" | sed "s/.*name='//;s/'.*//")
elif command -v aapt2 &>/dev/null; then
    PKG_NAME=$(aapt2 dump badging "$APK_PATH" 2>/dev/null | grep "package: name=" | sed "s/.*name='//;s/'.*//")
else
    PKG_NAME=""
    warn "aapt not available. Cannot auto-launch; open from Waydroid launcher."
fi

if [[ -n "$PKG_NAME" ]]; then
    info "Package name: ${PKG_NAME}"
    info "Launching app..."
    waydroid app launch "$PKG_NAME" 2>/dev/null && \
        ok "App launched: ${PKG_NAME}" || \
        warn "Could not auto-launch. Open the app from the Waydroid launcher."
fi

ok "Done."
