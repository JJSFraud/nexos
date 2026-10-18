#!/usr/bin/env bash
# =============================================================================
# NexOS GPU Detector
# Outputs JSON: {"gpu":"<name>","type":"nvidia|amd|intel|none","driver":"<drv>"}
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
json_escape() {
    # Minimal JSON string escaping
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    echo "$s"
}

emit() {
    local gpu="$1" type="$2" driver="$3"
    gpu=$(json_escape "$gpu")
    driver=$(json_escape "$driver")
    printf '{"gpu":"%s","type":"%s","driver":"%s"}\n' "$gpu" "$type" "$driver"
}

# ---------------------------------------------------------------------------
# Try lspci first (most reliable on Linux)
# ---------------------------------------------------------------------------
detect_via_lspci() {
    if ! command -v lspci &>/dev/null; then
        return 1
    fi

    local lspci_out
    lspci_out=$(lspci 2>/dev/null)

    # ---- NVIDIA ----
    local nvidia_line
    nvidia_line=$(echo "$lspci_out" | grep -i "NVIDIA" | grep -iE "VGA|3D|Display" | head -1 || true)
    if [[ -n "$nvidia_line" ]]; then
        local gpu_name
        gpu_name=$(echo "$nvidia_line" | sed 's/.*: //' | sed 's/ (.*//')

        # Detect driver
        local driver="nouveau"
        if lsmod 2>/dev/null | grep -q "^nvidia "; then
            driver="nvidia (proprietary)"
        elif lsmod 2>/dev/null | grep -q "^nouveau "; then
            driver="nouveau (open-source)"
        fi

        emit "$gpu_name" "nvidia" "$driver"
        return 0
    fi

    # ---- AMD / ATI ----
    local amd_line
    amd_line=$(echo "$lspci_out" | grep -iE "AMD|ATI|Radeon" | grep -iE "VGA|3D|Display" | head -1 || true)
    if [[ -n "$amd_line" ]]; then
        local gpu_name
        gpu_name=$(echo "$amd_line" | sed 's/.*: //' | sed 's/ (.*//')

        local driver="radeon"
        if lsmod 2>/dev/null | grep -q "^amdgpu "; then
            driver="amdgpu"
        elif lsmod 2>/dev/null | grep -q "^radeon "; then
            driver="radeon"
        fi

        emit "$gpu_name" "amd" "$driver"
        return 0
    fi

    # ---- Intel ----
    local intel_line
    intel_line=$(echo "$lspci_out" | grep -iE "Intel.*VGA|Intel.*Display|Intel.*Graphics|Intel.*UHD|Intel.*HD|Intel.*Iris" | head -1 || true)
    if [[ -n "$intel_line" ]]; then
        local gpu_name
        gpu_name=$(echo "$intel_line" | sed 's/.*: //' | sed 's/ (.*//')

        local driver="i915"
        if lsmod 2>/dev/null | grep -q "^i915 "; then
            driver="i915 (integrated)"
        fi

        emit "$gpu_name" "intel" "$driver"
        return 0
    fi

    return 1
}

# ---------------------------------------------------------------------------
# Try /sys/class/drm as fallback
# ---------------------------------------------------------------------------
detect_via_drm() {
    local drm_dir="/sys/class/drm"
    [[ -d "$drm_dir" ]] || return 1

    for card in "${drm_dir}"/card*/; do
        [[ -d "$card" ]] || continue
        local vendor_file="${card}device/vendor"
        local device_file="${card}device/device"
        [[ -f "$vendor_file" ]] || continue

        local vendor_id
        vendor_id=$(cat "$vendor_file" 2>/dev/null || echo "0x0000")

        case "$vendor_id" in
            "0x10de") # NVIDIA
                local device_id
                device_id=$(cat "$device_file" 2>/dev/null || echo "unknown")
                emit "NVIDIA GPU (${device_id})" "nvidia" "nouveau"
                return 0
                ;;
            "0x1002") # AMD
                local device_id
                device_id=$(cat "$device_file" 2>/dev/null || echo "unknown")
                emit "AMD GPU (${device_id})" "amd" "amdgpu"
                return 0
                ;;
            "0x8086") # Intel
                local device_id
                device_id=$(cat "$device_file" 2>/dev/null || echo "unknown")
                emit "Intel GPU (${device_id})" "intel" "i915"
                return 0
                ;;
        esac
    done

    return 1
}

# ---------------------------------------------------------------------------
# Try glxinfo as additional fallback
# ---------------------------------------------------------------------------
detect_via_glxinfo() {
    if ! command -v glxinfo &>/dev/null; then
        return 1
    fi

    local renderer
    renderer=$(glxinfo 2>/dev/null | grep "OpenGL renderer string" | sed 's/OpenGL renderer string: //' || true)
    [[ -z "$renderer" ]] && return 1

    local type="none"
    local driver="unknown"

    if echo "$renderer" | grep -qi "nvidia"; then
        type="nvidia"; driver="nvidia"
    elif echo "$renderer" | grep -qi "radeon\|amd\|ati"; then
        type="amd"; driver="amdgpu"
    elif echo "$renderer" | grep -qi "intel\|mesa.*intel"; then
        type="intel"; driver="i915"
    elif echo "$renderer" | grep -qi "mesa\|llvm\|software"; then
        type="intel"; driver="mesa (software)"
    fi

    emit "$renderer" "$type" "$driver"
    return 0
}

# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------
if detect_via_lspci 2>/dev/null; then
    exit 0
elif detect_via_drm 2>/dev/null; then
    exit 0
elif detect_via_glxinfo 2>/dev/null; then
    exit 0
else
    # No GPU found or no detection tools available
    emit "No dedicated GPU detected (integrated/unknown)" "none" "vesa"
    exit 0
fi
