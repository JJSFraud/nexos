#!/usr/bin/env bash
# =============================================================================
# NexOS — Wine EXE Launcher
# Usage: launch-exe.sh <path-to-exe> [wine-args...]
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[Wine]${NC} $*"; }
ok()    { echo -e "${GREEN}[Wine]${NC} $*"; }
warn()  { echo -e "${YELLOW}[Wine]${NC} $*"; }
error() { echo -e "${RED}[Wine]${NC} $*"; exit 1; }

# ---------------------------------------------------------------------------
# Argument check
# ---------------------------------------------------------------------------
EXE_PATH="${1:-}"
if [[ -z "$EXE_PATH" ]]; then
    echo "Usage: $0 <path-to.exe> [extra wine arguments]"
    exit 1
fi
shift  # Remaining args forwarded to wine

# ---------------------------------------------------------------------------
# Check Wine installation
# ---------------------------------------------------------------------------
if ! command -v wine &>/dev/null; then
    error "Wine is not installed. Install it with: sudo apt-get install -y wine wine64"
fi

WINE_BIN=$(command -v wine64 2>/dev/null || command -v wine)
WINE_VERSION=$(wine --version 2>/dev/null || echo "unknown")
info "Wine: ${WINE_VERSION} (${WINE_BIN})"

# ---------------------------------------------------------------------------
# Validate EXE file
# ---------------------------------------------------------------------------
EXE_PATH=$(realpath -e "$EXE_PATH" 2>/dev/null) || \
    error "File not found: ${EXE_PATH}"

if [[ ! -f "$EXE_PATH" ]]; then
    error "Not a regular file: ${EXE_PATH}"
fi

# Check extension (case-insensitive)
EXT="${EXE_PATH##*.}"
EXT_LOWER="${EXT,,}"
if [[ "$EXT_LOWER" != "exe" && "$EXT_LOWER" != "msi" && "$EXT_LOWER" != "bat" && "$EXT_LOWER" != "com" ]]; then
    warn "File does not have a typical Windows extension (.exe/.msi/.bat/.com). Attempting anyway..."
fi

# Verify it looks like a PE/MZ binary (unless it's an MSI/script)
if [[ "$EXT_LOWER" == "exe" || "$EXT_LOWER" == "com" ]]; then
    MAGIC=$(xxd -l 2 "$EXE_PATH" 2>/dev/null | head -1 | awk '{print $2$3}' || true)
    if [[ "${MAGIC^^}" != "4D5A"* && "${MAGIC^^}" != "4D 5A"* ]]; then
        warn "File does not appear to be a valid PE executable (missing MZ header)."
    fi
fi

# ---------------------------------------------------------------------------
# WINEPREFIX setup
# ---------------------------------------------------------------------------
export WINEPREFIX="${WINEPREFIX:-${HOME}/.wine}"
export WINEARCH="${WINEARCH:-win64}"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-mscoree,mshtml=}"
export WINEDEBUG="${WINEDEBUG:--all}"   # suppress debug spam by default

info "WINEPREFIX: ${WINEPREFIX}"
info "WINEARCH:   ${WINEARCH}"

# Initialise prefix if it doesn't exist yet
if [[ ! -d "${WINEPREFIX}" ]]; then
    info "Initialising Wine prefix at ${WINEPREFIX}..."
    WINEDLLOVERRIDES="mscoree,mshtml=" wineboot --init 2>/dev/null &
    WINEBOOT_PID=$!
    # Wait up to 30s for wineserver to initialise
    for i in $(seq 1 30); do
        sleep 1
        kill -0 $WINEBOOT_PID 2>/dev/null || break
    done
    ok "Wine prefix initialised."
fi

# ---------------------------------------------------------------------------
# Detect if EXE needs 32-bit vs 64-bit
# ---------------------------------------------------------------------------
if command -v objdump &>/dev/null; then
    MACHINE=$(objdump -f "$EXE_PATH" 2>/dev/null | grep "file format" | head -1 || true)
    if echo "$MACHINE" | grep -qi "pei-i386"; then
        info "Detected 32-bit EXE — using wine (32-bit mode)."
        WINE_CMD="wine"
    else
        WINE_CMD="${WINE_BIN}"
    fi
else
    WINE_CMD="${WINE_BIN}"
fi

# ---------------------------------------------------------------------------
# Launch
# ---------------------------------------------------------------------------
info "Launching: $(basename "$EXE_PATH")"
info "Full path: ${EXE_PATH}"
info "Command:   ${WINE_CMD} \"${EXE_PATH}\" $*"
echo ""

# Run wine in background and capture exit code
set +e
"$WINE_CMD" "$EXE_PATH" "$@"
EXIT_CODE=$?
set -e

echo ""
if [[ $EXIT_CODE -eq 0 ]]; then
    ok "Application exited cleanly (code 0)."
else
    warn "Application exited with code ${EXIT_CODE}."
    if [[ $EXIT_CODE -eq 127 ]]; then
        error "Wine could not find the executable. Check the path and Wine installation."
    fi
fi

exit $EXIT_CODE
