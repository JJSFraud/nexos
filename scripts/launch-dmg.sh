#!/usr/bin/env bash
# =============================================================================
# NexOS — Darling DMG Launcher
# Usage: launch-dmg.sh <path-to.dmg>
# Requires: darling (https://www.darlinghq.org/) installed on the host
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[Darling]${NC} $*"; }
ok()    { echo -e "${GREEN}[Darling]${NC} $*"; }
warn()  { echo -e "${YELLOW}[Darling]${NC} $*"; }
error() { echo -e "${RED}[Darling]${NC} $*"; exit 1; }

# ---------------------------------------------------------------------------
# Argument check
# ---------------------------------------------------------------------------
DMG_PATH="${1:-}"
if [[ -z "$DMG_PATH" ]]; then
    echo "Usage: $0 <path-to.dmg>"
    exit 1
fi

# ---------------------------------------------------------------------------
# Validate DMG file
# ---------------------------------------------------------------------------
DMG_PATH=$(realpath -e "$DMG_PATH" 2>/dev/null) || \
    error "File not found: ${DMG_PATH}"

[[ -f "$DMG_PATH" ]] || error "Not a regular file: ${DMG_PATH}"

EXT="${DMG_PATH##*.}"
[[ "${EXT,,}" == "dmg" ]] || warn "File does not have .dmg extension. Proceeding anyway..."

info "DMG: $(basename "$DMG_PATH")"

# ---------------------------------------------------------------------------
# Check Darling installation
# ---------------------------------------------------------------------------
if ! command -v darling &>/dev/null; then
    error "Darling is not installed.
Install instructions: https://docs.darlinghq.org/build-instructions.html
Or: sudo apt-get install darling (if available in your distro's repo)"
fi

DARLING_VERSION=$(darling --version 2>/dev/null | head -1 || echo "unknown")
info "Darling: ${DARLING_VERSION}"

# ---------------------------------------------------------------------------
# Mount the DMG inside Darling's macOS environment
# ---------------------------------------------------------------------------
MOUNT_POINT="/Volumes/$(basename "$DMG_PATH" .dmg)"
info "Mounting DMG at: ${MOUNT_POINT}"

# Run hdiutil via darling shell
set +e
darling shell hdiutil attach "$DMG_PATH" -mountpoint "$MOUNT_POINT" -nobrowse -readonly
ATTACH_EXIT=$?
set -e

if [[ $ATTACH_EXIT -ne 0 ]]; then
    error "Failed to mount DMG (exit code ${ATTACH_EXIT}). The DMG may be encrypted or unsupported."
fi

ok "DMG mounted at ${MOUNT_POINT}"

# ---------------------------------------------------------------------------
# Find the .app bundle inside the DMG
# ---------------------------------------------------------------------------
info "Searching for .app bundle..."
APP_PATH=$(darling shell ls "${MOUNT_POINT}" 2>/dev/null | grep "\.app$" | head -1 || true)

if [[ -z "$APP_PATH" ]]; then
    warn "No .app bundle found at top-level of DMG."
    info "Contents of ${MOUNT_POINT}:"
    darling shell ls -la "${MOUNT_POINT}" 2>/dev/null || true

    # Try one level deeper
    APP_PATH=$(darling shell find "${MOUNT_POINT}" -maxdepth 2 -name "*.app" 2>/dev/null | head -1 || true)
    if [[ -z "$APP_PATH" ]]; then
        # Unmount and bail
        darling shell hdiutil detach "$MOUNT_POINT" 2>/dev/null || true
        error "No .app bundle found in DMG."
    fi
fi

info "Found app: ${APP_PATH}"

# ---------------------------------------------------------------------------
# Launch the app
# ---------------------------------------------------------------------------
APP_FULL_PATH="${MOUNT_POINT}/${APP_PATH}"
EXECUTABLE_NAME=$(darling shell defaults read "${APP_FULL_PATH}/Contents/Info" CFBundleExecutable 2>/dev/null || \
                  echo "$(basename "$APP_PATH" .app)")

info "Launching: ${EXECUTABLE_NAME}"

set +e
darling shell "${APP_FULL_PATH}/Contents/MacOS/${EXECUTABLE_NAME}"
LAUNCH_EXIT=$?
set -e

echo ""
if [[ $LAUNCH_EXIT -eq 0 ]]; then
    ok "Application exited cleanly (code 0)."
else
    warn "Application exited with code ${LAUNCH_EXIT}."
fi

# ---------------------------------------------------------------------------
# Unmount DMG after app exits
# ---------------------------------------------------------------------------
info "Unmounting DMG..."
darling shell hdiutil detach "$MOUNT_POINT" -force 2>/dev/null || \
    warn "Could not unmount ${MOUNT_POINT} — it may still be in use."

ok "Done."
exit $LAUNCH_EXIT
