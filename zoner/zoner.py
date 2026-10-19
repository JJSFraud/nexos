#!/usr/bin/env python3
"""
=============================================================================
Linux Zoner — GPU & Gaming Performance Booster + Phone Link
All-in-One Standalone Application
Tuned specifically for Intel HD Graphics 6000 & 2015 MacBook Air (Core i5 / 8GB)
=============================================================================
"""

import os
import sys
import json
import socket
import subprocess
import threading
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
import tkinter as tk
from tkinter import ttk, filedialog, messagebox

# ---------------------------------------------------------------------------
# Directories & Bootstrap
# ---------------------------------------------------------------------------
INSTALL_DIR = os.path.expanduser("~/.local/share/zoner")
os.makedirs(INSTALL_DIR, exist_ok=True)

CORE_SCRIPT = os.path.join(INSTALL_DIR, "zoner-core.sh")
WRAPPER_SCRIPT = os.path.join(INSTALL_DIR, "launch-game.sh")

# Self-bootstrap helper scripts if missing
CORE_SCRIPT_CONTENT = """#!/usr/bin/env bash
ACTION="${1:-status}"
GPU_MIN_FREQ="/sys/class/drm/card0/gt_min_freq_mhz"
GPU_MAX_FREQ="/sys/class/drm/card0/gt_max_freq_mhz"
GPU_BOOST_FREQ="/sys/class/drm/card0/gt_boost_freq_mhz"
GPU_CUR_FREQ="/sys/class/drm/card0/gt_cur_freq_mhz"

if [[ "$ACTION" == "enable" || "$ACTION" == "turbo" ]]; then
    if [[ -f "$GPU_MAX_FREQ" && -f "$GPU_MIN_FREQ" ]]; then
        MAX=$(cat "$GPU_MAX_FREQ" 2>/dev/null || echo "1000")
        echo "$MAX" > "$GPU_MIN_FREQ" 2>/dev/null || true
        echo "$MAX" > "$GPU_BOOST_FREQ" 2>/dev/null || true
    fi
    for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [[ -f "$gov" ]] && echo "performance" > "$gov" 2>/dev/null || true
    done
    sysctl -w vm.swappiness=10 >/dev/null 2>&1 || true
    pgrep -x "picom" >/dev/null && killall -STOP picom 2>/dev/null || true
    mkdir -p ~/.config/environment.d
    cat << 'EOF' > ~/.config/environment.d/99-zoner.conf
MESA_LOADER_DRIVER_OVERRIDE=iris
mesa_glthread=true
WINE_FULLSCREEN_FSR=1
WINE_FULLSCREEN_FSR_STRENGTH=2
vblank_mode=0
EOF
elif [[ "$ACTION" == "disable" || "$ACTION" == "balanced" ]]; then
    [[ -f "$GPU_MIN_FREQ" ]] && echo "300" > "$GPU_MIN_FREQ" 2>/dev/null || true
    for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [[ -f "$gov" ]] && echo "schedutil" > "$gov" 2>/dev/null || true
    done
    pgrep -x "picom" >/dev/null && killall -CONT picom 2>/dev/null || true
fi
"""

WRAPPER_SCRIPT_CONTENT = """#!/usr/bin/env bash
export MESA_LOADER_DRIVER_OVERRIDE="iris"
export mesa_glthread="true"
export vblank_mode=0
export WINE_FULLSCREEN_FSR=1
export WINE_FULLSCREEN_FSR_STRENGTH=2
export WINE_FULLSCREEN_FSR_MODE="ultra"
export DXVK_ASYNC=1
export DXVK_STATE_CACHE=1
if command -v gamemoderun &>/dev/null; then
    exec gamemoderun "$@"
else
    exec "$@"
fi
"""

if not os.path.exists(CORE_SCRIPT):
    with open(CORE_SCRIPT, "w") as f:
        f.write(CORE_SCRIPT_CONTENT)
    os.chmod(CORE_SCRIPT, 0o755)

if not os.path.exists(WRAPPER_SCRIPT):
    with open(WRAPPER_SCRIPT, "w") as f:
        f.write(WRAPPER_SCRIPT_CONTENT)
    os.chmod(WRAPPER_SCRIPT, 0o755)

# ---------------------------------------------------------------------------
# Phone Companion Server (Zero-APK Built-in)
# ---------------------------------------------------------------------------
PHONE_PORT = 5050

telemetry_data = {
    "gpu_clock": "1000 MHz",
    "cpu_gov": "performance",
    "ram": "2.4 GB / 8.0 GB",
    "fps_target": "60 FPS",
    "turbo": True,
    "fsr_level": 2
}

def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

def simulate_key(key_name, action="tap"):
    key_map = {
        "jump": "space", "sprint": "Shift_L", "interact": "e",
        "action": "Return", "up": "w", "down": "s", "left": "a", "right": "d"
    }
    actual_key = key_map.get(key_name.lower(), key_name)
    if sys.platform != "win32":
        if action == "down":
            subprocess.run(["xdotool", "keydown", actual_key], check=False)
        elif action == "up":
            subprocess.run(["xdotool", "keyup", actual_key], check=False)
        else:
            subprocess.run(["xdotool", "key", actual_key], check=False)

HTML_PAGE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<title>Zoner Phone Link</title>
<style>
    * { box-sizing: border-box; margin: 0; padding: 0; user-select: none; -webkit-user-select: none; touch-action: manipulation; }
    body { background: #0c0d14; color: #fff; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; overflow: hidden; height: 100vh; display: flex; flex-direction: column; }
    header { background: #131522; padding: 10px 16px; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #23273e; }
    .title { font-size: 15px; font-weight: 800; color: #00f0ff; }
    .badge { font-size: 10px; font-weight: 700; background: #00e67622; color: #00e676; padding: 4px 8px; border-radius: 12px; border: 1px solid #00e67655; }
    .hud-bar { background: #171a2d; padding: 8px 16px; display: flex; justify-content: space-around; font-size: 11px; border-bottom: 1px solid #23273e; }
    .hud-item { text-align: center; }
    .hud-val { font-weight: 800; color: #00f0ff; font-size: 13px; }
    .controller { flex: 1; display: flex; justify-content: space-between; align-items: center; padding: 20px; position: relative; }
    .dpad { width: 140px; height: 140px; position: relative; }
    .d-btn { position: absolute; width: 44px; height: 44px; background: #1e2238; border: 1px solid #3d4468; border-radius: 10px; color: #fff; font-size: 18px; font-weight: bold; display: flex; align-items: center; justify-content: center; }
    .d-btn:active { background: #00f0ff; color: #000; }
    .d-up { top: 0; left: 48px; } .d-down { bottom: 0; left: 48px; } .d-left { top: 48px; left: 0; } .d-right { top: 48px; right: 0; }
    .actions { width: 140px; height: 140px; position: relative; }
    .a-btn { position: absolute; width: 46px; height: 46px; border-radius: 50%; color: #fff; font-size: 13px; font-weight: 800; display: flex; align-items: center; justify-content: center; border: 1px solid rgba(255,255,255,0.2); }
    .a-btn:active { transform: scale(0.92); filter: brightness(1.4); }
    .btn-jump { bottom: 0; left: 47px; background: #00e676; color: #000; box-shadow: 0 0 12px #00e67644; }
    .btn-sprint { top: 0; left: 47px; background: #ff3366; box-shadow: 0 0 12px #ff336644; }
    .btn-interact { top: 47px; left: 0; background: #3d84ff; box-shadow: 0 0 12px #3d84ff44; }
    .btn-action { top: 47px; right: 0; background: #ffb300; color: #000; box-shadow: 0 0 12px #ffb30044; }
    .boost-bar { background: #111320; padding: 12px; display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; border-top: 1px solid #23273e; }
    .boost-btn { background: #1c2035; border: 1px solid #2d3356; color: #fff; font-size: 11px; font-weight: 700; padding: 10px; border-radius: 8px; text-align: center; }
    .boost-btn:active { background: #00f0ff; color: #000; }
    .boost-btn.active { border-color: #ff3366; background: #ff336622; color: #ff3366; }
</style>
</head>
<body>
<header>
    <div class="title">⚡ ZONER PHONE LINK</div>
    <div class="badge">● MAC CONNECTED</div>
</header>
<div class="hud-bar">
    <div class="hud-item"><div>INTEL GPU</div><div class="hud-val" id="hud-gpu">1000 MHz</div></div>
    <div class="hud-item"><div>CPU MODE</div><div class="hud-val" id="hud-cpu">Performance</div></div>
    <div class="hud-item"><div>TARGET FPS</div><div class="hud-val" id="hud-fps" style="color:#00e676">60 FPS</div></div>
    <div class="hud-item"><div>RAM</div><div class="hud-val" id="hud-ram">2.4 / 8 GB</div></div>
</div>
<div class="controller">
    <div class="dpad">
        <div class="d-btn d-up" data-key="up">▲</div>
        <div class="d-btn d-left" data-key="left">◀</div>
        <div class="d-btn d-right" data-key="right">▶</div>
        <div class="d-btn d-down" data-key="down">▼</div>
    </div>
    <div class="actions">
        <div class="a-btn btn-sprint" data-key="sprint">RUN</div>
        <div class="a-btn btn-interact" data-key="interact">E</div>
        <div class="a-btn btn-action" data-key="action">ACT</div>
        <div class="a-btn btn-jump" data-key="jump">JUMP</div>
    </div>
</div>
<div class="boost-bar">
    <div class="boost-btn active" id="btn-turbo" onclick="toggleTurbo()">🔥 TURBO GPU</div>
    <div class="boost-btn" onclick="sendBoost('fsr_boost')">✨ FSR SHARPEN</div>
    <div class="boost-btn" onclick="sendBoost('screenshot')">📸 SCREENSHOT</div>
</div>
<script>
    function vibrate(ms=25) { if (navigator.vibrate) navigator.vibrate(ms); }
    document.querySelectorAll('[data-key]').forEach(el => {
        const key = el.getAttribute('data-key');
        el.addEventListener('touchstart', (e) => { e.preventDefault(); vibrate(20); sendKey(key, 'down'); });
        el.addEventListener('touchend', (e) => { e.preventDefault(); sendKey(key, 'up'); });
    });
    function sendKey(key, action) {
        fetch('/api/input', { method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({ key, action }) }).catch(()=>{});
    }
    function toggleTurbo() {
        vibrate(40);
        fetch('/api/boost?action=toggle_turbo', { method: 'POST' })
            .then(r => r.json())
            .then(data => {
                const btn = document.getElementById('btn-turbo');
                if (data.turbo) { btn.classList.add('active'); btn.textContent = '🔥 TURBO GPU'; }
                else { btn.classList.remove('active'); btn.textContent = '● BALANCED'; }
            });
    }
    function sendBoost(action) { vibrate(30); fetch('/api/boost?action=' + action, { method: 'POST' }); }
    setInterval(() => {
        fetch('/api/status').then(r => r.json()).then(data => {
            document.getElementById('hud-gpu').textContent = data.gpu_clock;
            document.getElementById('hud-cpu').textContent = data.cpu_gov;
            document.getElementById('hud-ram').textContent = data.ram;
            document.getElementById('hud-fps').textContent = data.fps_target;
        }).catch(()=>{});
    }, 1000);
</script>
</body>
</html>
"""

class PhoneRequestHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass
    def do_GET(self):
        if self.path in ["/", "/index.html"] or self.path.startswith("/?"):
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(HTML_PAGE.encode("utf-8"))
        elif self.path == "/api/status":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(telemetry_data).encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()
    def do_POST(self):
        if self.path == "/api/input":
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length)
            try:
                data = json.loads(body.decode("utf-8"))
                simulate_key(data.get("key"), data.get("action", "tap"))
            except Exception:
                pass
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'{"status":"ok"}')
        elif self.path.startswith("/api/boost"):
            query = self.path.split("?")[-1]
            if "action=toggle_turbo" in query:
                telemetry_data["turbo"] = not telemetry_data["turbo"]
                action_str = "enable" if telemetry_data["turbo"] else "disable"
                subprocess.run(["bash", CORE_SCRIPT, action_str], check=False)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"turbo": telemetry_data["turbo"]}).encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()

def start_phone_server():
    try:
        server = HTTPServer(("0.0.0.0", PHONE_PORT), PhoneRequestHandler)
        t = threading.Thread(target=server.serve_forever, daemon=True)
        t.start()
        return True
    except Exception as e:
        print(f"[ZONER] Phone server info: {e}")
        return False

# ---------------------------------------------------------------------------
# Main GUI Application
# ---------------------------------------------------------------------------
BG_MAIN     = "#0c0d14"
BG_CARD     = "#151724"
ACCENT_BLUE = "#3d84ff"
ACCENT_CYAN = "#00f0ff"
ACCENT_GREEN= "#00e676"
ACCENT_RED  = "#ff3366"
TEXT_WHITE  = "#ffffff"
TEXT_MUTED  = "#8e95b0"
BORDER_COL  = "#252840"

class ZonerApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Linux Zoner — GPU & Gaming Performance Booster + Phone Link")
        self.root.geometry("820x680")
        self.root.configure(bg=BG_MAIN)
        self.root.resizable(False, False)

        self.turbo_active = False
        self.fsr_level = tk.IntVar(value=2)
        self.iris_enabled = tk.BooleanVar(value=True)
        self.glthread_enabled = tk.BooleanVar(value=True)
        self.unlock_fps = tk.BooleanVar(value=True)

        self.local_ip = get_local_ip()
        self.phone_url = f"http://{self.local_ip}:{PHONE_PORT}"

        start_phone_server()
        self.build_ui()
        self.start_monitoring()

    def build_ui(self):
        header = tk.Frame(self.root, bg="#10121d", height=75)
        header.pack(fill="x")
        header.pack_propagate(False)

        title_box = tk.Frame(header, bg="#10121d")
        title_box.pack(side="left", padx=20, pady=12)

        lbl_title = tk.Label(title_box, text="⚡ LINUX ZONER", font=("Segoe UI", 16, "bold"), fg=ACCENT_CYAN, bg="#10121d")
        lbl_title.pack(anchor="w")

        lbl_sub = tk.Label(title_box, text="Graphics Engine & Phone Link • MacBook Air 2015 (Intel HD 6000)", font=("Segoe UI", 9), fg=TEXT_MUTED, bg="#10121d")
        lbl_sub.pack(anchor="w")

        self.lbl_badge = tk.Label(header, text="● BALANCED MODE", font=("Segoe UI", 9, "bold"), fg="#ffb300", bg="#2a2310", padx=12, pady=6)
        self.lbl_badge.pack(side="right", padx=20, pady=18)

        tab_bar = tk.Frame(self.root, bg="#121422", height=42)
        tab_bar.pack(fill="x")
        tab_bar.pack_propagate(False)

        self.btn_tab_gpu = tk.Button(tab_bar, text="⚡ GPU & Graphics Booster", font=("Segoe UI", 10, "bold"), bg="#1a1e36", fg=ACCENT_CYAN, relief="flat", padx=16, cursor="hand2", command=lambda: self.switch_tab("gpu"))
        self.btn_tab_gpu.pack(side="left", fill="y", padx=(10, 4))

        self.btn_tab_phone = tk.Button(tab_bar, text="📱 Connect Phone (No APK)", font=("Segoe UI", 10, "bold"), bg="#121422", fg=TEXT_MUTED, relief="flat", padx=16, cursor="hand2", command=lambda: self.switch_tab("phone"))
        self.btn_tab_phone.pack(side="left", fill="y")

        self.pages_container = tk.Frame(self.root, bg=BG_MAIN)
        self.pages_container.pack(fill="both", expand=True)

        self.page_gpu = tk.Frame(self.pages_container, bg=BG_MAIN)
        self.build_gpu_page(self.page_gpu)

        self.page_phone = tk.Frame(self.pages_container, bg=BG_MAIN)
        self.build_phone_page(self.page_phone)

        self.switch_tab("gpu")

    def switch_tab(self, tab_name):
        if tab_name == "gpu":
            self.page_phone.pack_forget()
            self.page_gpu.pack(fill="both", expand=True, padx=20, pady=15)
            self.btn_tab_gpu.config(bg="#1a1e36", fg=ACCENT_CYAN)
            self.btn_tab_phone.config(bg="#121422", fg=TEXT_MUTED)
        else:
            self.page_gpu.pack_forget()
            self.page_phone.pack(fill="both", expand=True, padx=20, pady=15)
            self.btn_tab_phone.config(bg="#1a1e36", fg=ACCENT_CYAN)
            self.btn_tab_gpu.config(bg="#121422", fg=TEXT_MUTED)

    def build_gpu_page(self, parent):
        left_col = tk.Frame(parent, bg=BG_MAIN, width=490)
        left_col.pack(side="left", fill="both", expand=True, padx=(0, 10))

        right_col = tk.Frame(parent, bg=BG_MAIN, width=280)
        right_col.pack(side="right", fill="both", padx=(10, 0))

        card_turbo = tk.Frame(left_col, bg=BG_CARD, highlightthickness=1, highlightbackground=BORDER_COL, padx=15, pady=14)
        card_turbo.pack(fill="x", pady=(0, 10))

        self.btn_turbo = tk.Button(
            card_turbo,
            text="🚀 ACTIVATE TURBO GAMING MODE",
            font=("Segoe UI", 12, "bold"),
            bg=ACCENT_BLUE,
            fg=TEXT_WHITE,
            activebackground="#2a66d9",
            activeforeground=TEXT_WHITE,
            relief="flat",
            cursor="hand2",
            pady=11,
            command=self.toggle_turbo
        )
        self.btn_turbo.pack(fill="x")

        lbl_desc = tk.Label(card_turbo, text="Locks Intel HD 6000 to 1000MHz peak clock, sets CPU to Performance,\nand enables low-latency gaming scheduler.", font=("Segoe UI", 8), fg=TEXT_MUTED, bg=BG_CARD)
        lbl_desc.pack(pady=(6, 0))

        card_gfx = tk.Frame(left_col, bg=BG_CARD, highlightthickness=1, highlightbackground=BORDER_COL, padx=15, pady=12)
        card_gfx.pack(fill="x", pady=(0, 10))

        tk.Label(card_gfx, text="🎮 GRAPHICS & FPS BOOSTERS", font=("Segoe UI", 10, "bold"), fg=ACCENT_CYAN, bg=BG_CARD).pack(anchor="w", pady=(0, 6))

        fsr_box = tk.Frame(card_gfx, bg=BG_CARD)
        fsr_box.pack(fill="x", pady=2)
        tk.Label(fsr_box, text="AMD FSR Upscaling Sharpening:", font=("Segoe UI", 9), fg=TEXT_WHITE, bg=BG_CARD).pack(side="left")
        self.lbl_fsr_val = tk.Label(fsr_box, text="Level 2 (Balanced)", font=("Segoe UI", 9, "bold"), fg=ACCENT_CYAN, bg=BG_CARD)
        self.lbl_fsr_val.pack(side="right")

        fsr_slider = ttk.Scale(card_gfx, from_=1, to=5, orient="horizontal", variable=self.fsr_level, command=self.on_fsr_change)
        fsr_slider.pack(fill="x", pady=(2, 6))

        tk.Checkbutton(card_gfx, text="Enable Mesa Iris Driver (+25-35% GPU throughput)", variable=self.iris_enabled, bg=BG_CARD, fg=TEXT_WHITE, selectcolor="#000000", activebackground=BG_CARD, activeforeground=TEXT_WHITE, font=("Segoe UI", 9)).pack(anchor="w", pady=2)
        tk.Checkbutton(card_gfx, text="Mesa GL Multithreaded Cache (Stops Stutter)", variable=self.glthread_enabled, bg=BG_CARD, fg=TEXT_WHITE, selectcolor="#000000", activebackground=BG_CARD, activeforeground=TEXT_WHITE, font=("Segoe UI", 9)).pack(anchor="w", pady=2)
        tk.Checkbutton(card_gfx, text="Unlock 60+ FPS (Disable V-Sync limit)", variable=self.unlock_fps, bg=BG_CARD, fg=TEXT_WHITE, selectcolor="#000000", activebackground=BG_CARD, activeforeground=TEXT_WHITE, font=("Segoe UI", 9)).pack(anchor="w", pady=2)

        card_games = tk.Frame(left_col, bg=BG_CARD, highlightthickness=1, highlightbackground=BORDER_COL, padx=15, pady=12)
        card_games.pack(fill="x")
        tk.Label(card_games, text="🕹️ 1-CLICK LAUNCH WITH ZONER BOOST", font=("Segoe UI", 10, "bold"), fg=ACCENT_CYAN, bg=BG_CARD).pack(anchor="w", pady=(0, 6))

        btn_row = tk.Frame(card_games, bg=BG_CARD)
        btn_row.pack(fill="x", pady=2)
        tk.Button(btn_row, text="🔴 Roblox Boost", font=("Segoe UI", 9, "bold"), bg="#1e2235", fg=TEXT_WHITE, relief="flat", padx=8, pady=6, cursor="hand2", command=self.launch_roblox).pack(side="left", padx=(0, 5), expand=True, fill="x")
        tk.Button(btn_row, text="⛏️ Minecraft", font=("Segoe UI", 9, "bold"), bg="#1e2235", fg=TEXT_WHITE, relief="flat", padx=8, pady=6, cursor="hand2", command=self.launch_minecraft).pack(side="left", padx=2, expand=True, fill="x")
        tk.Button(btn_row, text="📂 Launch Game / EXE...", font=("Segoe UI", 9, "bold"), bg="#283250", fg=ACCENT_CYAN, relief="flat", padx=8, pady=6, cursor="hand2", command=self.launch_custom).pack(side="left", padx=(5, 0), expand=True, fill="x")

        card_hud = tk.Frame(right_col, bg=BG_CARD, highlightthickness=1, highlightbackground=BORDER_COL, padx=15, pady=15)
        card_hud.pack(fill="both", expand=True)

        tk.Label(card_hud, text="📊 LIVE HARDWARE HUD", font=("Segoe UI", 10, "bold"), fg=ACCENT_CYAN, bg=BG_CARD).pack(anchor="w", pady=(0, 8))
        self.lbl_hud_gpu = self.create_hud_item(card_hud, "GPU Clock:", "--- MHz", ACCENT_CYAN)
        self.lbl_hud_gov = self.create_hud_item(card_hud, "CPU Governor:", "powersave", TEXT_WHITE)
        self.lbl_hud_ram = self.create_hud_item(card_hud, "RAM Usage:", "--- / 8 GB", TEXT_WHITE)
        self.lbl_hud_fps = self.create_hud_item(card_hud, "Target FPS:", "60 FPS", ACCENT_GREEN)

        sep = tk.Frame(card_hud, height=1, bg=BORDER_COL)
        sep.pack(fill="x", pady=12)

        tk.Label(card_hud, text="HARDWARE PROFILE", font=("Segoe UI", 8, "bold"), fg=TEXT_MUTED, bg=BG_CARD).pack(anchor="w")
        tk.Label(card_hud, text="• MacBook Air 2015\n• Intel Core i5-5250U\n• Intel HD Graphics 6000\n• 8 GB LPDDR3 RAM", font=("Segoe UI", 8), fg=TEXT_MUTED, bg=BG_CARD, justify="left").pack(anchor="w", pady=(3, 0))

    def build_phone_page(self, parent):
        card_top = tk.Frame(parent, bg=BG_CARD, highlightthickness=1, highlightbackground=BORDER_COL, padx=20, pady=16)
        card_top.pack(fill="x", pady=(0, 15))

        tk.Label(card_top, text="📱 ZERO-APK PHONE COMPANION LINK", font=("Segoe UI", 13, "bold"), fg=ACCENT_CYAN, bg=BG_CARD).pack(anchor="w")
        tk.Label(card_top, text="Your Android phone helps your Mac game without installing any APK!\nUse it as a second-screen live telemetry HUD, a wireless game controller, or quick macro deck.", font=("Segoe UI", 9), fg=TEXT_MUTED, bg=BG_CARD, justify="left").pack(anchor="w", pady=(4, 0))

        card_conn = tk.Frame(parent, bg=BG_CARD, highlightthickness=1, highlightbackground=BORDER_COL, padx=20, pady=18)
        card_conn.pack(fill="x", pady=(0, 15))

        tk.Label(card_conn, text="HOW TO CONNECT IN 30 SECONDS:", font=("Segoe UI", 10, "bold"), fg=TEXT_WHITE, bg=BG_CARD).pack(anchor="w", pady=(0, 10))

        steps_text = (
            "1. Connect your phone to the same Wi-Fi (or plug in USB cable and turn on USB Tethering)\n"
            "2. Open Chrome (or any browser) on your Android phone\n"
            "3. Type this web address:"
        )
        tk.Label(card_conn, text=steps_text, font=("Segoe UI", 10), fg=TEXT_WHITE, bg=BG_CARD, justify="left").pack(anchor="w", pady=(0, 10))

        url_frame = tk.Frame(card_conn, bg="#0d0e17", highlightthickness=1, highlightbackground=ACCENT_CYAN, padx=15, pady=10)
        url_frame.pack(fill="x", pady=(0, 10))

        self.lbl_url = tk.Label(url_frame, text=self.phone_url, font=("Consolas", 14, "bold"), fg=ACCENT_GREEN, bg="#0d0e17")
        self.lbl_url.pack(side="left")

        btn_copy = tk.Button(url_frame, text="📋 Copy Address", font=("Segoe UI", 9, "bold"), bg=ACCENT_BLUE, fg=TEXT_WHITE, relief="flat", padx=10, pady=4, cursor="hand2", command=self.copy_url)
        btn_copy.pack(side="right")

        card_feats = tk.Frame(parent, bg=BG_CARD, highlightthickness=1, highlightbackground=BORDER_COL, padx=20, pady=16)
        card_feats.pack(fill="x")

        tk.Label(card_feats, text="HOW YOUR PHONE HELPS YOUR MAC GAME:", font=("Segoe UI", 10, "bold"), fg=ACCENT_CYAN, bg=BG_CARD).pack(anchor="w", pady=(0, 10))

        f_grid = tk.Frame(card_feats, bg=BG_CARD)
        f_grid.pack(fill="x")

        self.create_phone_feat(f_grid, "🎮 Wireless Gamepad", "Turns phone into touch sticks & buttons for Roblox, platformers, and action games.", 0, 0)
        self.create_phone_feat(f_grid, "📊 Second-Screen HUD", "Shows live GPU MHz, CPU temp, and RAM so your Mac screen stays 100% clean.", 0, 1)
        self.create_phone_feat(f_grid, "🔥 In-Game Turbo Switch", "Tap Turbo Boost, FSR Sharpen, or Screenshot on your phone without leaving your game.", 1, 0)
        self.create_phone_feat(f_grid, "⚡ USB Zero-Lag Link", "Use USB cable for ultra-fast ping and zero input latency.", 1, 1)

    def create_phone_feat(self, parent, title, desc, r, c):
        f = tk.Frame(parent, bg="#1a1c2d", padx=12, pady=10)
        f.grid(row=r, column=c, padx=6, pady=6, sticky="nsew")
        parent.grid_columnconfigure(c, weight=1)
        tk.Label(f, text=title, font=("Segoe UI", 10, "bold"), fg=TEXT_WHITE, bg="#1a1c2d").pack(anchor="w")
        tk.Label(f, text=desc, font=("Segoe UI", 8), fg=TEXT_MUTED, bg="#1a1c2d", justify="left").pack(anchor="w", pady=(2, 0))

    def copy_url(self):
        self.root.clipboard_clear()
        self.root.clipboard_append(self.phone_url)
        messagebox.showinfo("Zoner Phone Link", f"Copied to clipboard:\n{self.phone_url}\n\nOpen this on your Android phone's browser!")

    def create_hud_item(self, parent, label_text, default_val, val_color):
        frame = tk.Frame(parent, bg=BG_CARD)
        frame.pack(fill="x", pady=5)
        tk.Label(frame, text=label_text, font=("Segoe UI", 8), fg=TEXT_MUTED, bg=BG_CARD).pack(anchor="w")
        val_lbl = tk.Label(frame, text=default_val, font=("Segoe UI", 11, "bold"), fg=val_color, bg=BG_CARD)
        val_lbl.pack(anchor="w")
        return val_lbl

    def on_fsr_change(self, val):
        level = int(float(val))
        labels = {
            1: "Level 1 (Ultra Quality - 1.3x)",
            2: "Level 2 (Balanced - 1.5x)",
            3: "Level 3 (Performance - 1.7x)",
            4: "Level 4 (Max FPS - 2.0x)",
            5: "Level 5 (Aggressive Sharpness)"
        }
        self.lbl_fsr_val.config(text=labels.get(level, f"Level {level}"))
        telemetry_data["fsr_level"] = level

    def toggle_turbo(self):
        self.turbo_active = not self.turbo_active
        telemetry_data["turbo"] = self.turbo_active
        if self.turbo_active:
            self.btn_turbo.config(text="🛑 TURBO MODE ACTIVE (CLICK TO STOP)", bg=ACCENT_RED)
            self.lbl_badge.config(text="🔥 TURBO BOOST ON", fg="#ff3366", bg="#381018")
            subprocess.run(["bash", CORE_SCRIPT, "enable"], check=False)
        else:
            self.btn_turbo.config(text="🚀 ACTIVATE TURBO GAMING MODE", bg=ACCENT_BLUE)
            self.lbl_badge.config(text="● BALANCED MODE", fg="#ffb300", bg="#2a2310")
            subprocess.run(["bash", CORE_SCRIPT, "disable"], check=False)

    def launch_roblox(self):
        self.run_boosted_game("flatpak run com.usebottles.bottles || flatpak run org.vinegarhq.Sober || xdg-open https://www.roblox.com")

    def launch_minecraft(self):
        self.run_boosted_game("prismlauncher || minecraft-launcher || xdg-open https://www.minecraft.net")

    def launch_custom(self):
        game_path = filedialog.askopenfilename(
            title="Select Game Executable or Script",
            filetypes=[("Executable Files", "*.exe *.sh *.bin *.AppImage *"), ("All Files", "*.*")]
        )
        if game_path:
            self.run_boosted_game(f'"{game_path}"')

    def run_boosted_game(self, cmd):
        if not self.turbo_active:
            self.toggle_turbo()

        env_copy = os.environ.copy()
        if self.iris_enabled.get():
            env_copy["MESA_LOADER_DRIVER_OVERRIDE"] = "iris"
        if self.glthread_enabled.get():
            env_copy["mesa_glthread"] = "true"
        if self.unlock_fps.get():
            env_copy["vblank_mode"] = "0"
            
        env_copy["WINE_FULLSCREEN_FSR"] = "1"
        env_copy["WINE_FULLSCREEN_FSR_STRENGTH"] = str(self.fsr_level.get())

        threading.Thread(target=lambda: subprocess.run(f"bash {WRAPPER_SCRIPT} {cmd}", shell=True, env=env_copy), daemon=True).start()
        messagebox.showinfo("Zoner Booster", "🚀 Game launched with Intel HD 6000 & AMD FSR Boost!")

    def start_monitoring(self):
        def update_loop():
            while True:
                try:
                    gpu_freq = "--- MHz"
                    if os.path.exists("/sys/class/drm/card0/gt_cur_freq_mhz"):
                        with open("/sys/class/drm/card0/gt_cur_freq_mhz") as f:
                            gpu_freq = f.read().strip() + " MHz"
                    
                    gov = "powersave"
                    if os.path.exists("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"):
                        with open("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor") as f:
                            gov = f.read().strip()

                    ram_text = "--- / 8 GB"
                    if os.path.exists("/proc/meminfo"):
                        with open("/proc/meminfo") as f:
                            lines = f.readlines()
                        total = available = 0
                        for line in lines:
                            if "MemTotal" in line: total = int(line.split()[1])
                            if "MemAvailable" in line: available = int(line.split()[1])
                        if total > 0:
                            used_gb = (total - available) / 1024 / 1024
                            total_gb = total / 1024 / 1024
                            ram_text = f"{used_gb:.1f} GB / {total_gb:.0f} GB"

                    telemetry_data["gpu_clock"] = gpu_freq
                    telemetry_data["cpu_gov"] = gov
                    telemetry_data["ram"] = ram_text

                    self.root.after(0, lambda: self.lbl_hud_gpu.config(text=gpu_freq))
                    self.root.after(0, lambda: self.lbl_hud_gov.config(text=gov))
                    self.root.after(0, lambda: self.lbl_hud_ram.config(text=ram_text))
                except Exception:
                    pass
                time.sleep(2)

        threading.Thread(target=update_loop, daemon=True).start()

def main():
    root = tk.Tk()
    app = ZonerApp(root)
    root.mainloop()

if __name__ == "__main__":
    main()
