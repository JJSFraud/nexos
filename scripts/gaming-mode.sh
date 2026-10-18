#!/usr/bin/env bash
# =============================================================================
# NexOS Gaming Mode Toggle
# Usage: gaming-mode.sh on | off
# Must be run with root privileges (called via sudo from the shell).
# =============================================================================
set -euo pipefail

MODE="${1:-}"
[[ -z "$MODE" ]] && { echo "Usage: $0 on|off"; exit 1; }
[[ "$MODE" != "on" && "$MODE" != "off" ]] && { echo "Usage: $0 on|off"; exit 1; }

# Colours
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info() { echo -e "${CYAN}[Gaming Mode]${NC} $*"; }
ok()   { echo -e "${GREEN}[Gaming Mode]${NC} $*"; }
warn() { echo -e "${YELLOW}[Gaming Mode]${NC} $*"; }

# ---------------------------------------------------------------------------
# CPU Governor helpers
# ---------------------------------------------------------------------------
set_cpu_governor() {
    local governor="$1"
    local changed=0
    for path in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [[ -w "$path" ]] || continue
        echo "$governor" > "$path" && (( changed++ )) || true
    done
    info "CPU governor set to '${governor}' on ${changed} core(s)."
}

read_cpu_governor() {
    local g
    g=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
    echo "$g"
}

# ---------------------------------------------------------------------------
# GPU Performance helpers
# ---------------------------------------------------------------------------
set_nvidia_performance() {
    local mode="$1"   # 0=auto 1=perf
    if command -v nvidia-smi &>/dev/null; then
        nvidia-smi --gom="$mode" 2>/dev/null || true
        if [[ "$mode" == "1" ]]; then
            nvidia-settings -a "[gpu:0]/GpuPowerMizerMode=1" 2>/dev/null || true
        else
            nvidia-settings -a "[gpu:0]/GpuPowerMizerMode=0" 2>/dev/null || true
        fi
        info "NVIDIA GPU power mode set to $([ "$mode" == "1" ] && echo "Performance" || echo "Auto")."
    fi
}

set_amd_performance() {
    local level="$1"   # high | auto
    local amd_path
    for amd_path in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
        [[ -w "$amd_path" ]] && echo "$level" > "$amd_path" && \
            info "AMD GPU performance level set to '${level}'." || true
    done
}

set_intel_performance() {
    local mode="$1"   # max_performance | balanced
    local intel_path
    for intel_path in /sys/devices/system/cpu/intel_pstate/no_turbo; do
        [[ -w "$intel_path" ]] || continue
        if [[ "$mode" == "max_performance" ]]; then
            echo "0" > "$intel_path"   # enable turbo
        else
            echo "0" > "$intel_path"
        fi
    done
}

detect_gpu_type() {
    if lspci 2>/dev/null | grep -qi "NVIDIA"; then echo "nvidia"
    elif lspci 2>/dev/null | grep -qi "AMD\|ATI"; then echo "amd"
    elif lspci 2>/dev/null | grep -qi "Intel.*Graphics\|Intel.*UHD\|Intel.*HD"; then echo "intel"
    else echo "none"
    fi
}

# ---------------------------------------------------------------------------
# Services to stop in gaming mode
# ---------------------------------------------------------------------------
NON_ESSENTIAL_SERVICES=(
    cups
    cups-browsed
    bluetooth
    avahi-daemon
    ModemManager
    whoopsie
    kerneloops
    colord
    geoclue
    speech-dispatcher
    anacron
)

stop_services() {
    info "Stopping non-essential services..."
    for svc in "${NON_ESSENTIAL_SERVICES[@]}"; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            systemctl stop "$svc" 2>/dev/null && info "  Stopped: $svc" || warn "  Could not stop: $svc"
        fi
    done
}

start_services() {
    info "Restoring non-essential services..."
    for svc in "${NON_ESSENTIAL_SERVICES[@]}"; do
        # Only restart if the unit file exists
        if systemctl cat "$svc" &>/dev/null; then
            systemctl start "$svc" 2>/dev/null && info "  Started: $svc" || warn "  Could not start: $svc"
        fi
    done
}

# ---------------------------------------------------------------------------
# Kill background processes that steal RAM/CPU
# ---------------------------------------------------------------------------
kill_background_hogs() {
    info "Killing background resource hogs..."
    local hogs=(
        "tracker-store"
        "tracker-miner-fs"
        "tracker-extract"
        "gvfs-udisks2-volume-monitor"
        "evolution-source-registry"
        "evolution-calendar-factory"
        "telepathy-gabble"
    )
    for proc in "${hogs[@]}"; do
        pkill -x "$proc" 2>/dev/null && info "  Killed: $proc" || true
    done
}

# ---------------------------------------------------------------------------
# Memory optimisation
# ---------------------------------------------------------------------------
set_swappiness() {
    local val="$1"
    sysctl -w vm.swappiness="$val" 2>/dev/null && info "vm.swappiness = ${val}" || true
}

set_dirty_ratio() {
    local ratio="$1"
    sysctl -w vm.dirty_ratio="$ratio" 2>/dev/null || true
    sysctl -w vm.dirty_background_ratio="$(( ratio / 2 ))" 2>/dev/null || true
    info "vm.dirty_ratio = ${ratio}"
}

drop_caches() {
    info "Dropping page cache..."
    sync
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# GAMING MODE ON
# ---------------------------------------------------------------------------
gaming_on() {
    info "============================================"
    info " Enabling Gaming Mode..."
    info "============================================"

    # 1. CPU performance
    set_cpu_governor "performance"

    # 2. GPU performance
    GPU_TYPE=$(detect_gpu_type)
    info "Detected GPU type: ${GPU_TYPE}"
    case "$GPU_TYPE" in
        nvidia) set_nvidia_performance "1" ;;
        amd)    set_amd_performance "high" ;;
        intel)  set_intel_performance "max_performance" ;;
        *)      warn "No dedicated GPU detected; skipping GPU tuning." ;;
    esac

    # 3. Stop services
    stop_services

    # 4. Kill hogs
    kill_background_hogs

    # 5. Memory tweaks
    set_swappiness 10
    set_dirty_ratio 40
    drop_caches

    # 6. IRQ affinity — move IRQs off CPU0 if possible
    if [[ -f /proc/irq/default_smp_affinity ]]; then
        echo "fe" > /proc/irq/default_smp_affinity 2>/dev/null || true
    fi

    # 7. Scheduler tweaks
    sysctl -w kernel.sched_min_granularity_ns=500000 2>/dev/null || true
    sysctl -w kernel.sched_wakeup_granularity_ns=1000000 2>/dev/null || true

    # 8. Persist state
    echo "on" > /tmp/nexos-gaming-mode

    ok "============================================"
    ok " Gaming Mode ON 🎮"
    ok " CPU: performance | GPU: ${GPU_TYPE} high"
    ok " Swappiness: 10 | Background services: OFF"
    ok "============================================"
}

# ---------------------------------------------------------------------------
# GAMING MODE OFF
# ---------------------------------------------------------------------------
gaming_off() {
    info "============================================"
    info " Disabling Gaming Mode..."
    info "============================================"

    # 1. Restore CPU governor
    set_cpu_governor "schedutil"

    # 2. Restore GPU
    GPU_TYPE=$(detect_gpu_type)
    case "$GPU_TYPE" in
        nvidia) set_nvidia_performance "0" ;;
        amd)    set_amd_performance "auto" ;;
        intel)  set_intel_performance "balanced" ;;
    esac

    # 3. Restart services
    start_services

    # 4. Restore memory
    set_swappiness 60
    set_dirty_ratio 20

    # 5. Restore scheduler
    sysctl -w kernel.sched_min_granularity_ns=2250000 2>/dev/null || true
    sysctl -w kernel.sched_wakeup_granularity_ns=3000000 2>/dev/null || true

    # 6. Persist state
    echo "off" > /tmp/nexos-gaming-mode

    ok "============================================"
    ok " Gaming Mode OFF"
    ok " CPU: schedutil | GPU: auto | Normal mode"
    ok "============================================"
}

# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------
if [[ "$MODE" == "on" ]]; then
    gaming_on
else
    gaming_off
fi
