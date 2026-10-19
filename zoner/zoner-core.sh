#!/usr/bin/env bash
# =============================================================================
# Linux Zoner Core Engine — Intel HD 6000 & Mac Gaming Optimizer
# =============================================================================

set -e

ACTION="${1:-status}"

# Intel GPU sysfs paths
GPU_MIN_FREQ="/sys/class/drm/card0/gt_min_freq_mhz"
GPU_MAX_FREQ="/sys/class/drm/card0/gt_max_freq_mhz"
GPU_BOOST_FREQ="/sys/class/drm/card0/gt_boost_freq_mhz"
GPU_CUR_FREQ="/sys/class/drm/card0/gt_cur_freq_mhz"

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------

enable_gaming_mode() {
    echo "[ZONER] Activating Gaming Boost Mode..."

    # 1. Lock Intel HD 6000 GPU to Peak Frequency
    if [[ -f "$GPU_MAX_FREQ" && -f "$GPU_MIN_FREQ" ]]; then
        MAX_FREQ=$(cat "$GPU_MAX_FREQ" 2>/dev/null || echo "1000")
        echo "$MAX_FREQ" > "$GPU_MIN_FREQ" 2>/dev/null || true
        echo "$MAX_FREQ" > "$GPU_BOOST_FREQ" 2>/dev/null || true
        echo "[ZONER] Intel GPU locked to peak frequency: ${MAX_FREQ}MHz"
    fi

    # 2. Set CPU Governor to Performance
    for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [[ -f "$gov" ]]; then
            echo "performance" | sudo tee "$gov" >/dev/null 2>&1 || echo "performance" > "$gov" 2>/dev/null || true
        fi
    done
    echo "[ZONER] CPU Governor set to 'performance' for all cores."

    # 3. Kernel Memory & Swappiness Optimization
    sudo sysctl -w vm.swappiness=10 >/dev/null 2>&1 || true
    sudo sysctl -w vm.vfs_cache_pressure=50 >/dev/null 2>&1 || true

    # 4. Suspend Desktop Compositor (stops screen tearing & frees VRAM)
    if pgrep -x "picom" >/dev/null; then
        killall -STOP picom 2>/dev/null || true
        echo "[ZONER] Suspended picom compositor for lower latency."
    fi
    if command -v xfconf-query &>/dev/null; then
        xfconf-query -c xfwm4 -p /general/use_compositing -s false 2>/dev/null || true
    fi

    # 5. Enable Intel Iris Driver & FSR in environment
    mkdir -p ~/.config/environment.d
    cat << 'EOF' > ~/.config/environment.d/99-zoner.conf
MESA_LOADER_DRIVER_OVERRIDE=iris
mesa_glthread=true
WINE_FULLSCREEN_FSR=1
WINE_FULLSCREEN_FSR_STRENGTH=2
vblank_mode=0
EOF

    echo "[ZONER] Turbo Gaming Mode is ACTIVE!"
}

disable_gaming_mode() {
    echo "[ZONER] Restoring Balanced Mode..."

    # 1. Restore dynamic Intel GPU frequency
    if [[ -f "$GPU_MIN_FREQ" ]]; then
        echo "300" | sudo tee "$GPU_MIN_FREQ" >/dev/null 2>&1 || echo "300" > "$GPU_MIN_FREQ" 2>/dev/null || true
        echo "[ZONER] Intel GPU dynamic frequency scaling restored."
    fi

    # 2. Restore CPU Governor
    for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [[ -f "$gov" ]]; then
            echo "schedutil" | sudo tee "$gov" >/dev/null 2>&1 || echo "schedutil" > "$gov" 2>/dev/null || true
        fi
    done
    echo "[ZONER] CPU Governor restored to 'schedutil'."

    # 3. Resume Desktop Compositor
    if pgrep -x "picom" >/dev/null; then
        killall -CONT picom 2>/dev/null || true
    fi
    if command -v xfconf-query &>/dev/null; then
        xfconf-query -c xfwm4 -p /general/use_compositing -s true 2>/dev/null || true
    fi

    echo "[ZONER] Balanced Mode is ACTIVE."
}

get_status() {
    CPU_GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
    GPU_FREQ=$(cat "$GPU_CUR_FREQ" 2>/dev/null || echo "unknown")
    SWAP=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo "unknown")
    
    echo "{"
    echo "  \"cpu_governor\": \"$CPU_GOV\","
    echo "  \"gpu_frequency_mhz\": \"$GPU_FREQ\","
    echo "  \"swappiness\": \"$SWAP\","
    if [[ "$CPU_GOV" == "performance" ]]; then
        echo "  \"gaming_mode\": true"
    else
        echo "  \"gaming_mode\": false"
    fi
    echo "}"
}

# ---------------------------------------------------------------------------
# Dispatcher
# ---------------------------------------------------------------------------

case "$ACTION" in
    enable|on|turbo)
        enable_gaming_mode
        ;;
    disable|off|balanced)
        disable_gaming_mode
        ;;
    status)
        get_status
        ;;
    *)
        echo "Usage: $0 {enable|disable|status}"
        exit 1
        ;;
esac
