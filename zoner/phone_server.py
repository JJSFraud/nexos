#!/usr/bin/env python3
"""
=============================================================================
Zoner Phone Link Server — Zero-APK Android Companion for Linux Gaming
Serves a high-performance touch controller and live telemetry HUD to any phone.
=============================================================================
"""

import os
import sys
import json
import socket
import subprocess
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler

PHONE_PORT = 5050

# State shared with main Zoner GUI
telemetry_data = {
    "gpu_clock": "1000 MHz",
    "cpu_gov": "performance",
    "ram": "2.4 GB / 8.0 GB",
    "fps_target": "60 FPS",
    "turbo": True,
    "fsr_level": 2,
    "connected_clients": 0
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

# ---------------------------------------------------------------------------
# Key Input Simulator (Zero APK required — Phone sends touch, Mac receives key)
# ---------------------------------------------------------------------------
def simulate_key(key_name, action="tap"):
    # Map common game controls
    key_map = {
        "jump": "space",
        "sprint": "Shift_L",
        "interact": "e",
        "action": "Return",
        "up": "w",
        "down": "s",
        "left": "a",
        "right": "d",
        "crouch": "Control_L"
    }
    actual_key = key_map.get(key_name.lower(), key_name)

    if sys.platform != "win32":
        if action == "down":
            subprocess.run(["xdotool", "keydown", actual_key], check=False)
        elif action == "up":
            subprocess.run(["xdotool", "keyup", actual_key], check=False)
        else:
            subprocess.run(["xdotool", "key", actual_key], check=False)
    else:
        # Windows fallback if testing locally
        pass

# ---------------------------------------------------------------------------
# Embedded Mobile Web App (Zero APK, loads in phone's Chrome browser)
# ---------------------------------------------------------------------------
HTML_PAGE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<title>Zoner Phone Link</title>
<style>
    * { box-sizing: border-box; margin: 0; padding: 0; user-select: none; -webkit-user-select: none; touch-action: manipulation; }
    body { background: #0c0d14; color: #fff; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; overflow: hidden; height: 100vh; display: flex; flex-direction: column; }
    
    /* Header */
    header { background: #131522; padding: 10px 16px; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #23273e; }
    .title { font-size: 15px; font-weight: 800; color: #00f0ff; display: flex; align-items: center; gap: 6px; }
    .badge { font-size: 10px; font-weight: 700; background: #00e67622; color: #00e676; padding: 4px 8px; border-radius: 12px; border: 1px solid #00e67655; }
    
    /* HUD bar */
    .hud-bar { background: #171a2d; padding: 8px 16px; display: flex; justify-content: space-around; font-size: 11px; border-bottom: 1px solid #23273e; }
    .hud-item { text-align: center; }
    .hud-val { font-weight: 800; color: #00f0ff; font-size: 13px; }
    
    /* Controls Container */
    .controller { flex: 1; display: flex; justify-content: space-between; align-items: center; padding: 20px; position: relative; }
    
    /* D-PAD / Movement */
    .dpad { width: 140px; height: 140px; position: relative; }
    .d-btn { position: absolute; width: 44px; height: 44px; background: #1e2238; border: 1px solid #3d4468; border-radius: 10px; color: #fff; font-size: 18px; font-weight: bold; display: flex; align-items: center; justify-content: center; }
    .d-btn:active { background: #00f0ff; color: #000; }
    .d-up { top: 0; left: 48px; }
    .d-down { bottom: 0; left: 48px; }
    .d-left { top: 48px; left: 0; }
    .d-right { top: 48px; right: 0; }
    
    /* Action Buttons */
    .actions { width: 140px; height: 140px; position: relative; }
    .a-btn { position: absolute; width: 46px; height: 46px; border-radius: 50%; color: #fff; font-size: 14px; font-weight: 800; display: flex; align-items: center; justify-content: center; border: 1px solid rgba(255,255,255,0.2); }
    .a-btn:active { transform: scale(0.92); filter: brightness(1.4); }
    .btn-jump { bottom: 0; left: 47px; background: #00e676; color: #000; box-shadow: 0 0 12px #00e67644; }
    .btn-sprint { top: 0; left: 47px; background: #ff3366; box-shadow: 0 0 12px #ff336644; }
    .btn-interact { top: 47px; left: 0; background: #3d84ff; box-shadow: 0 0 12px #3d84ff44; }
    .btn-action { top: 47px; right: 0; background: #ffb300; color: #000; box-shadow: 0 0 12px #ffb30044; }
    
    /* Quick Boost Deck */
    .boost-bar { background: #111320; padding: 12px; display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; border-top: 1px solid #23273e; }
    .boost-btn { background: #1c2035; border: 1px solid #2d3356; color: #fff; font-size: 11px; font-weight: 700; padding: 10px; border-radius: 8px; text-align: center; }
    .boost-btn:active { background: #00f0ff; color: #000; }
    .boost-btn.active { border-color: #ff3366; background: #ff336622; color: #ff3366; }
</style>
</head>
<body>

<header>
    <div class="title">⚡ ZONER PHONE LINK</div>
    <div class="badge" id="conn-status">● MAC CONNECTED</div>
</header>

<div class="hud-bar">
    <div class="hud-item"><div>INTEL GPU</div><div class="hud-val" id="hud-gpu">1000 MHz</div></div>
    <div class="hud-item"><div>CPU MODE</div><div class="hud-val" id="hud-cpu">Performance</div></div>
    <div class="hud-item"><div>TARGET FPS</div><div class="hud-val" id="hud-fps" style="color:#00e676">60 FPS</div></div>
    <div class="hud-item"><div>RAM</div><div class="hud-val" id="hud-ram">2.4 / 8 GB</div></div>
</div>

<div class="controller">
    <!-- D-PAD / Movement -->
    <div class="dpad">
        <div class="d-btn d-up" data-key="up">▲</div>
        <div class="d-btn d-left" data-key="left">◀</div>
        <div class="d-btn d-right" data-key="right">▶</div>
        <div class="d-btn d-down" data-key="down">▼</div>
    </div>
    
    <!-- Action Buttons -->
    <div class="actions">
        <div class="a-btn btn-sprint" data-key="sprint">RUN</div>
        <div class="a-btn btn-interact" data-key="interact">E</div>
        <div class="a-btn btn-action" data-key="action">ACT</div>
        <div class="a-btn btn-jump" data-key="jump">JUMP</div>
    </div>
</div>

<!-- Bottom Game Booster Toolbar -->
<div class="boost-bar">
    <div class="boost-btn active" id="btn-turbo" onclick="toggleTurbo()">🔥 TURBO GPU</div>
    <div class="boost-btn" onclick="sendBoost('fsr_boost')">✨ FSR SHARPEN</div>
    <div class="boost-btn" onclick="sendBoost('screenshot')">📸 SCREENSHOT</div>
</div>

<script>
    function vibrate(ms=25) { if (navigator.vibrate) navigator.vibrate(ms); }

    // Touch controls with zero latency
    document.querySelectorAll('[data-key]').forEach(el => {
        const key = el.getAttribute('data-key');
        
        el.addEventListener('touchstart', (e) => {
            e.preventDefault();
            vibrate(20);
            sendKey(key, 'down');
        });
        
        el.addEventListener('touchend', (e) => {
            e.preventDefault();
            sendKey(key, 'up');
        });
    });

    function sendKey(key, action) {
        fetch('/api/input', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({ key, action })
        }).catch(()=>{});
    }

    function toggleTurbo() {
        vibrate(40);
        fetch('/api/boost?action=toggle_turbo', { method: 'POST' })
            .then(r => r.json())
            .then(data => {
                const btn = document.getElementById('btn-turbo');
                if (data.turbo) {
                    btn.classList.add('active');
                    btn.textContent = '🔥 TURBO GPU';
                } else {
                    btn.classList.remove('active');
                    btn.textContent = '● BALANCED';
                }
            });
    }

    function sendBoost(action) {
        vibrate(30);
        fetch('/api/boost?action=' + action, { method: 'POST' });
    }

    // Live Telemetry Poller (500ms)
    setInterval(() => {
        fetch('/api/status')
            .then(r => r.json())
            .then(data => {
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
        pass  # Suppress console logging for high performance

    def do_GET(self):
        if self.path == "/" or self.path.startswith("/?"):
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
                key = data.get("key")
                action = data.get("action", "tap")
                simulate_key(key, action)
            except Exception:
                pass
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'{"status":"ok"}')
        elif self.path.startswith("/api/boost"):
            query = self.path.split("?")[-1]
            if "action=toggle_turbo" in query:
                telemetry_data["turbo"] = not telemetry_data["turbo"]
                # Run zoner core
                action_str = "enable" if telemetry_data["turbo"] else "disable"
                core_script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "zoner-core.sh")
                subprocess.run(["bash", core_script, action_str], check=False)
                
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"turbo": telemetry_data["turbo"]}).encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()

def start_server(port=PHONE_PORT):
    server = HTTPServer(("0.0.0.0", port), PhoneRequestHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return server
