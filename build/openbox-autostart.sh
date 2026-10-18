#!/usr/bin/env bash
# =============================================================================
# NexOS — Openbox Autostart
# Launched by Openbox on session start (placed at ~/.config/openbox/autostart)
# =============================================================================

# ---------------------------------------------------------------------------
# Utility: run a command only if it exists
# ---------------------------------------------------------------------------
run_if_exists() {
    local cmd="$1"; shift
    if command -v "$cmd" &>/dev/null; then
        "$cmd" "$@" &
    fi
}

# ---------------------------------------------------------------------------
# 1. Set environment
# ---------------------------------------------------------------------------
export XDG_CURRENT_DESKTOP=NexOS
export NEXOS_CONFIG_DIR="${HOME}/.config/nexos"
export WINEPREFIX="${HOME}/.wine"
export WINEARCH="win64"
export PATH="${PATH}:/opt/nexos/scripts"
mkdir -p "${NEXOS_CONFIG_DIR}"

# ---------------------------------------------------------------------------
# 2. PulseAudio (audio server)
# ---------------------------------------------------------------------------
pulseaudio --start --exit-idle-time=-1 2>/dev/null || true

# ---------------------------------------------------------------------------
# 3. Compositor — picom with glassmorphism blur
# ---------------------------------------------------------------------------
# Kill existing instance if any
pkill -x picom 2>/dev/null || true
sleep 0.2

picom \
    --daemon \
    --backend glx \
    --vsync \
    --blur-method dual_kawase \
    --blur-strength 7 \
    --shadow \
    --shadow-radius 18 \
    --shadow-opacity 0.6 \
    --shadow-offset-x -12 \
    --shadow-offset-y -12 \
    --fading \
    --fade-in-step 0.03 \
    --fade-out-step 0.03 \
    --fade-delta 5 \
    --corner-radius 16 \
    --rounded-corners-exclude "window_type = 'dock'" \
    --inactive-opacity 0.95 \
    --active-opacity 1.0 \
    --opacity-rule "100:window_type = 'dock'" \
    --opacity-rule "100:window_type = 'desktop'" \
    2>/dev/null &

# ---------------------------------------------------------------------------
# 4. Wallpaper — nitrogen
# ---------------------------------------------------------------------------
sleep 0.3
if command -v nitrogen &>/dev/null; then
    nitrogen --restore 2>/dev/null || \
    nitrogen --set-auto "${NEXOS_CONFIG_DIR}/wallpaper" 2>/dev/null || \
    # Fallback: set solid dark colour
    xsetroot -solid "#0a0a1a" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# 5. Network applet
# ---------------------------------------------------------------------------
sleep 0.5
run_if_exists nm-applet --indicator

# ---------------------------------------------------------------------------
# 6. Plank dock (if enabled in config)
# ---------------------------------------------------------------------------
DOCK_ENABLED=$(python3 -c "
import json, os
cfg = os.path.expanduser('~/.config/nexos/nexos.conf')
if os.path.exists(cfg):
    with open(cfg) as f:
        d = json.load(f)
    print('true' if d.get('appearance',{}).get('dockEnabled', True) else 'false')
else:
    print('true')
" 2>/dev/null || echo 'true')

if [[ "${DOCK_ENABLED}" == "true" ]]; then
    run_if_exists plank
fi

# ---------------------------------------------------------------------------
# 7. System tray utilities
# ---------------------------------------------------------------------------
# Volume icon
run_if_exists pasystray
# Bluetooth tray (if bluetooth is enabled)
# run_if_exists blueman-applet

# ---------------------------------------------------------------------------
# 8. Keyboard / input setup
# ---------------------------------------------------------------------------
run_if_exists setxkbmap us
# Disable screen blanking and DPMS for desktop use
xset s off 2>/dev/null || true
xset -dpms 2>/dev/null || true
xset s noblank 2>/dev/null || true

# ---------------------------------------------------------------------------
# 9. NexOS Shell (Electron app) — main desktop
# ---------------------------------------------------------------------------
sleep 0.8

NEXOS_SHELL_DIRS=(
    "/opt/nexos-shell/nexos-shell"
    "/opt/nexos/shell"
    "${HOME}/nexos-shell/nexos-shell"
    "${HOME}/nexos/shell"
)

SHELL_LAUNCHED=false
for dir in "${NEXOS_SHELL_DIRS[@]}"; do
    if [[ -x "${dir}" ]]; then
        # Standalone binary
        "${dir}" --no-sandbox 2>/dev/null &
        SHELL_LAUNCHED=true
        break
    elif [[ -f "${dir}/main.js" ]]; then
        # Development mode
        if command -v electron &>/dev/null; then
            electron "${dir}" --no-sandbox 2>/dev/null &
            SHELL_LAUNCHED=true
            break
        elif command -v npm &>/dev/null; then
            (cd "${dir}" && npm start) 2>/dev/null &
            SHELL_LAUNCHED=true
            break
        fi
    fi
done

if ! $SHELL_LAUNCHED; then
    # Ultimate fallback: launch a basic Openbox menu-based desktop
    notify-send "NexOS" "Shell not found. Using fallback desktop." 2>/dev/null || true
    # Open a terminal so the user can do something
    xterm -geometry 80x24+100+100 -title "NexOS Terminal" &
fi

# ---------------------------------------------------------------------------
# 10. Notify ready
# ---------------------------------------------------------------------------
sleep 1
notify-send "NexOS" "Welcome to NexOS ${NEXOS_VERSION:-0.1.0-demo}! 🚀" \
    --icon=info --urgency=low 2>/dev/null || true

echo "[NexOS autostart] Desktop ready."
