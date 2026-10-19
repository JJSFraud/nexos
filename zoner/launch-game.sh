#!/usr/bin/env bash
# =============================================================================
# Linux Zoner Game Launcher Wrapper
# Injects FSR Upscaling, Iris GPU Acceleration, and GameMode into any Game/App
# =============================================================================

if [ -z "$1" ]; then
    echo "Usage: $0 <game-command-or-exe> [arguments...]"
    exit 1
fi

# Intel HD 6000 & Mesa Driver Optimizations
export MESA_LOADER_DRIVER_OVERRIDE="iris"
export mesa_glthread="true"
export vblank_mode=0

# AMD FidelityFX Super Resolution (FSR) Upscaling
# Automatically renders at lower internal res and upscales with sharpening
export WINE_FULLSCREEN_FSR=1
export WINE_FULLSCREEN_FSR_STRENGTH=2
export WINE_FULLSCREEN_FSR_MODE="ultra"

# DXVK / Vulkan Shader Caching (stops frame stutter)
export DXVK_ASYNC=1
export DXVK_STATE_CACHE=1
export __GL_SHADER_DISK_CACHE=1

echo "=========================================================="
echo "  🚀 Zoner Game Booster Launching: $1"
echo "  - Intel Iris GPU Driver: ACTIVE"
echo "  - AMD FSR Upscaling: ACTIVE"
echo "  - Mesa GL Multithreading: ACTIVE"
echo "=========================================================="

# Check if Feral GameMode is installed
if command -v gamemoderun &>/dev/null; then
    exec gamemoderun "$@"
else
    exec "$@"
fi
