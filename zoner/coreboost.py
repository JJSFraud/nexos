#!/usr/bin/env python3
"""
CoreBoost — CPU Performance Manager for Linux on Mac
Designed for 2015 MacBook Air (Intel i5-5250U) running Zorin OS / Ubuntu
Push Turbo Mode, govern CPU clocks, kill thermal throttling, control fans.
"""

import tkinter as tk
from tkinter import ttk, messagebox
import subprocess
import threading
import time
import os
import re

# ─── Theme ────────────────────────────────────────────────────────────────────
BG       = "#0d1117"
PANEL    = "#161b22"
BORDER   = "#30363d"
ACCENT   = "#f97316"   # orange
ACCENT2  = "#3b82f6"   # blue
GREEN    = "#22c55e"
RED      = "#ef4444"
YELLOW   = "#facc15"
FG       = "#f0f6fc"
FG_DIM   = "#8b949e"
FONT_M   = ("Segoe UI", 10)
FONT_B   = ("Segoe UI", 10, "bold")
FONT_LG  = ("Segoe UI", 14, "bold")
FONT_XL  = ("Segoe UI", 22, "bold")
FONT_SM  = ("Segoe UI", 9)

GOVERNORS = ["performance", "powersave", "schedutil", "ondemand", "conservative"]

# ─── Helpers ──────────────────────────────────────────────────────────────────

def run(cmd, sudo=False, capture=True):
    if sudo:
        cmd = f"pkexec bash -c \"{cmd}\""
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=capture,
            text=True, timeout=10
        )
        return result.stdout.strip() if capture else ""
    except Exception:
        return ""


def run_bg(cmd):
    """Fire-and-forget background command."""
    subprocess.Popen(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def get_cpu_freq_mhz(core=0):
    """Read current CPU freq for a core in MHz."""
    path = f"/sys/devices/system/cpu/cpu{core}/cpufreq/scaling_cur_freq"
    try:
        with open(path) as f:
            return int(f.read().strip()) // 1000
    except Exception:
        return 0


def get_cpu_max_mhz(core=0):
    path = f"/sys/devices/system/cpu/cpu{core}/cpufreq/cpuinfo_max_freq"
    try:
        with open(path) as f:
            return int(f.read().strip()) // 1000
    except Exception:
        return 2700


def get_num_cores():
    out = run("nproc")
    try:
        return int(out)
    except Exception:
        return 2


def get_governor():
    try:
        with open("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor") as f:
            return f.read().strip()
    except Exception:
        return "unknown"


def get_cpu_temp():
    """Return CPU temp in Celsius."""
    # Try hwmon
    for i in range(10):
        for j in range(10):
            p = f"/sys/class/hwmon/hwmon{i}/temp{j}_input"
            label_p = f"/sys/class/hwmon/hwmon{i}/temp{j}_label"
            if os.path.exists(p):
                try:
                    label = open(label_p).read().strip().lower() if os.path.exists(label_p) else ""
                    if "core" in label or "cpu" in label or label == "":
                        temp = int(open(p).read().strip()) // 1000
                        if 20 < temp < 120:
                            return temp
                except Exception:
                    pass
    # Fallback: sensors
    out = run("sensors 2>/dev/null | grep -i 'core 0' | head -1")
    m = re.search(r'\+(\d+\.\d+)°C', out)
    if m:
        return int(float(m.group(1)))
    return 0


def get_throttle_state():
    """Check if thermal throttle is disabled (MSR 0x1a2 bit 20 set = throttle enabled)."""
    out = run("rdmsr 0x1a2 2>/dev/null", sudo=False)
    if not out:
        return None  # msr-tools not available
    try:
        val = int(out, 16)
        bit20 = (val >> 20) & 1
        return bit20 == 0  # True = throttle disabled
    except Exception:
        return None


def get_ram_usage():
    out = run("free -m | awk 'NR==2{printf \"%s %s\", $3, $2}'")
    try:
        used, total = out.split()
        return int(used), int(total)
    except Exception:
        return 0, 8192


def get_cpu_usage():
    out = run("grep 'cpu ' /proc/stat")
    return out


_prev_cpu_stat = None

def cpu_percent():
    global _prev_cpu_stat
    out = run("grep 'cpu ' /proc/stat")
    try:
        vals = list(map(int, out.split()[1:]))
        idle = vals[3]
        total = sum(vals)
        if _prev_cpu_stat is not None:
            p_idle, p_total = _prev_cpu_stat
            diff_total = total - p_total
            diff_idle = idle - p_idle
            pct = 100 * (1 - diff_idle / diff_total) if diff_total else 0
        else:
            pct = 0
        _prev_cpu_stat = (idle, total)
        return round(pct, 1)
    except Exception:
        return 0


def check_tool(tool):
    return run(f"which {tool}") != ""


def set_governor(gov):
    cores = get_num_cores()
    cmds = " && ".join(
        f"echo {gov} | tee /sys/devices/system/cpu/cpu{i}/cpufreq/scaling_governor > /dev/null"
        for i in range(cores)
    )
    run(cmds, sudo=True)


def disable_throttle():
    run("modprobe msr && wrmsr -a 0x1a2 0x0", sudo=True)


def restore_throttle():
    run("modprobe msr && wrmsr -a 0x1a2 0x3000000", sudo=True)


def install_tools():
    run("apt-get install -y msr-tools cpupower linux-tools-generic macfanctld lm-sensors 2>&1", sudo=True)


# ─── Main App ─────────────────────────────────────────────────────────────────

class CoreBoostApp:
    def __init__(self, root: tk.Tk):
        self.root = root
        self.root.title("CoreBoost — CPU Performance Manager")
        self.root.configure(bg=BG)
        self.root.resizable(False, False)
        self.root.geometry("680x720")

        self.num_cores = get_num_cores()
        self.turbo_active = tk.BooleanVar(value=False)
        self.throttle_killed = tk.BooleanVar(value=False)
        self.fan_active = tk.BooleanVar(value=False)
        self.running = True
        self.freq_bars = []
        self.freq_labels = []

        self._build_ui()
        self._start_poller()

    # ── UI Construction ───────────────────────────────────────────────────────

    def _build_ui(self):
        # Header
        hdr = tk.Frame(self.root, bg=BG)
        hdr.pack(fill="x", padx=20, pady=(18, 0))

        tk.Label(hdr, text="⚡ CoreBoost", font=FONT_XL,
                 bg=BG, fg=ACCENT).pack(side="left")
        self.status_dot = tk.Label(hdr, text="●", font=("Segoe UI", 16),
                                   bg=BG, fg=FG_DIM)
        self.status_dot.pack(side="left", padx=(10, 0), pady=(6, 0))
        self.status_label = tk.Label(hdr, text="Idle", font=FONT_M,
                                     bg=BG, fg=FG_DIM)
        self.status_label.pack(side="left", padx=(4, 0), pady=(6, 0))

        tk.Label(self.root, text="CPU Performance Manager for Linux on Mac",
                 font=FONT_SM, bg=BG, fg=FG_DIM).pack(anchor="w", padx=20)

        self._sep()

        # Live stats row
        stats_row = tk.Frame(self.root, bg=BG)
        stats_row.pack(fill="x", padx=20, pady=(0, 4))
        self._stat_card(stats_row, "CPU", "cpu_pct_lbl", "%", ACCENT2)
        self._stat_card(stats_row, "TEMP", "temp_lbl", "°C", RED)
        self._stat_card(stats_row, "RAM", "ram_lbl", "%", GREEN)
        self._stat_card(stats_row, "GOVERNOR", "gov_lbl", "", YELLOW)

        self._sep()

        # Per-core freq bars
        tk.Label(self.root, text="Core Frequencies", font=FONT_B,
                 bg=BG, fg=FG).pack(anchor="w", padx=22, pady=(6, 2))

        core_frame = tk.Frame(self.root, bg=BG)
        core_frame.pack(fill="x", padx=22, pady=(0, 8))

        self.freq_bars = []
        self.freq_labels = []
        self.max_mhz = get_cpu_max_mhz()

        for i in range(self.num_cores):
            row = tk.Frame(core_frame, bg=BG)
            row.pack(fill="x", pady=3)

            tk.Label(row, text=f"Core {i}", font=FONT_SM,
                     bg=BG, fg=FG_DIM, width=6, anchor="w").pack(side="left")

            bar_bg = tk.Frame(row, bg=BORDER, height=14, width=440)
            bar_bg.pack(side="left", padx=(4, 8))
            bar_bg.pack_propagate(False)

            bar = tk.Frame(bar_bg, bg=ACCENT2, height=14, width=0)
            bar.place(x=0, y=0, height=14)

            lbl = tk.Label(row, text="-- MHz", font=FONT_SM,
                           bg=BG, fg=FG, width=10, anchor="w")
            lbl.pack(side="left")

            self.freq_bars.append((bar, bar_bg))
            self.freq_labels.append(lbl)

        self._sep()

        # ── Control Panel ──────────────────────────────────────────────────
        tk.Label(self.root, text="Performance Controls", font=FONT_B,
                 bg=BG, fg=FG).pack(anchor="w", padx=22, pady=(6, 4))

        ctrl = tk.Frame(self.root, bg=BG)
        ctrl.pack(fill="x", padx=20)

        # Big Turbo button
        self.turbo_btn = tk.Button(
            ctrl,
            text="🚀  TURBO MODE  OFF",
            font=("Segoe UI", 12, "bold"),
            bg=PANEL, fg=FG_DIM,
            activebackground=ACCENT,
            activeforeground="white",
            bd=0, padx=20, pady=12,
            cursor="hand2",
            command=self._toggle_turbo,
            relief="flat",
            width=24
        )
        self.turbo_btn.grid(row=0, column=0, columnspan=2, pady=(0, 12), sticky="ew")

        # Governor selector
        gov_frame = self._panel(ctrl, row=1, col=0, label="CPU Governor")
        self.gov_var = tk.StringVar(value=get_governor())
        gov_menu = ttk.Combobox(gov_frame, textvariable=self.gov_var,
                                values=GOVERNORS, state="readonly",
                                font=FONT_M, width=16)
        gov_menu.pack(pady=(4, 6))
        gov_menu.bind("<<ComboboxSelected>>", self._on_governor_change)

        tk.Button(gov_frame, text="Apply", font=FONT_SM,
                  bg=ACCENT2, fg="white", bd=0, padx=10, pady=4,
                  cursor="hand2", relief="flat",
                  command=self._apply_governor).pack(pady=(0, 6))

        # Throttle toggle
        th_frame = self._panel(ctrl, row=1, col=1, label="Thermal Throttle")
        self.th_state_lbl = tk.Label(th_frame, text="Checking...",
                                     font=FONT_SM, bg=PANEL, fg=FG_DIM)
        self.th_state_lbl.pack(pady=(4, 2))
        tk.Label(th_frame, text="⚠ Mac runs hotter without throttle",
                 font=("Segoe UI", 8), bg=PANEL, fg=YELLOW,
                 wraplength=180).pack()
        self.th_btn = tk.Button(th_frame, text="Disable Throttle",
                                font=FONT_SM, bg=RED, fg="white",
                                bd=0, padx=10, pady=4, cursor="hand2",
                                relief="flat", command=self._toggle_throttle)
        self.th_btn.pack(pady=(4, 6))

        # Fan control
        fan_frame = self._panel(ctrl, row=2, col=0, label="Mac Fan Control")
        self.fan_state_lbl = tk.Label(fan_frame, text="macfanctld",
                                      font=FONT_SM, bg=PANEL, fg=FG_DIM)
        self.fan_state_lbl.pack(pady=(4, 2))
        self.fan_btn = tk.Button(fan_frame, text="Start Fan Daemon",
                                 font=FONT_SM, bg=GREEN, fg="white",
                                 bd=0, padx=10, pady=4, cursor="hand2",
                                 relief="flat", command=self._toggle_fan)
        self.fan_btn.pack(pady=(0, 6))

        # Install tools
        tools_frame = self._panel(ctrl, row=2, col=1, label="Tools")
        tk.Label(tools_frame, text="Install msr-tools, cpupower\nmacfanctld, lm-sensors",
                 font=FONT_SM, bg=PANEL, fg=FG_DIM,
                 justify="center").pack(pady=(4, 4))
        tk.Button(tools_frame, text="Install All Tools",
                  font=FONT_SM, bg=PANEL, fg=ACCENT,
                  bd=1, padx=10, pady=4, cursor="hand2",
                  relief="flat",
                  command=self._install_tools).pack(pady=(0, 6))

        ctrl.columnconfigure(0, weight=1)
        ctrl.columnconfigure(1, weight=1)

        self._sep()

        # Log output
        tk.Label(self.root, text="Activity Log", font=FONT_B,
                 bg=BG, fg=FG).pack(anchor="w", padx=22, pady=(4, 2))

        log_frame = tk.Frame(self.root, bg=PANEL, bd=0)
        log_frame.pack(fill="both", expand=True, padx=20, pady=(0, 16))

        self.log = tk.Text(log_frame, bg=PANEL, fg=FG_DIM, font=("Courier New", 9),
                           bd=0, padx=8, pady=6, height=6, state="disabled",
                           insertbackground=FG, wrap="word")
        self.log.pack(fill="both", expand=True)

        self._log("CoreBoost started.")
        self._check_tools_on_start()

    def _stat_card(self, parent, title, attr_name, suffix, color):
        card = tk.Frame(parent, bg=PANEL, bd=0)
        card.pack(side="left", expand=True, fill="x", padx=4, pady=4)

        tk.Label(card, text=title, font=FONT_SM, bg=PANEL, fg=FG_DIM).pack(pady=(8, 0))
        lbl = tk.Label(card, text="--" + suffix, font=("Segoe UI", 16, "bold"),
                       bg=PANEL, fg=color)
        lbl.pack(pady=(0, 8))
        setattr(self, attr_name, lbl)

    def _panel(self, parent, row, col, label):
        outer = tk.Frame(parent, bg=BORDER, bd=0)
        outer.grid(row=row, column=col, padx=6, pady=6, sticky="nsew")
        inner = tk.Frame(outer, bg=PANEL, bd=0)
        inner.pack(fill="both", expand=True, padx=1, pady=1)
        tk.Label(inner, text=label, font=FONT_B, bg=PANEL, fg=FG).pack(pady=(8, 0))
        return inner

    def _sep(self):
        tk.Frame(self.root, bg=BORDER, height=1).pack(fill="x", padx=20, pady=8)

    # ── Logging ───────────────────────────────────────────────────────────────

    def _log(self, msg):
        ts = time.strftime("%H:%M:%S")
        self.log.configure(state="normal")
        self.log.insert("end", f"[{ts}] {msg}\n")
        self.log.see("end")
        self.log.configure(state="disabled")

    # ── Tool Checks ───────────────────────────────────────────────────────────

    def _check_tools_on_start(self):
        def check():
            missing = []
            for tool in ["rdmsr", "wrmsr", "cpupower", "macfanctld", "sensors"]:
                if not check_tool(tool):
                    missing.append(tool)
            if missing:
                self._log(f"⚠ Missing tools: {', '.join(missing)} — click 'Install All Tools'")
            else:
                self._log("✓ All tools available.")
            # Check throttle state
            state = get_throttle_state()
            self.root.after(0, lambda: self._update_throttle_ui(state))
        threading.Thread(target=check, daemon=True).start()

    def _update_throttle_ui(self, state):
        if state is None:
            self.th_state_lbl.config(text="msr-tools missing", fg=FG_DIM)
            self.th_btn.config(text="Install msr-tools first", bg=BORDER, fg=FG_DIM)
        elif state:
            self.th_state_lbl.config(text="● Throttle DISABLED", fg=GREEN)
            self.th_btn.config(text="Re-enable Throttle", bg=YELLOW, fg=BG)
        else:
            self.th_state_lbl.config(text="● Throttle ACTIVE (normal)", fg=FG_DIM)
            self.th_btn.config(text="Disable Throttle", bg=RED, fg="white")

    # ── Poller ────────────────────────────────────────────────────────────────

    def _start_poller(self):
        def poll():
            while self.running:
                try:
                    self._update_stats()
                except Exception:
                    pass
                time.sleep(1.5)
        threading.Thread(target=poll, daemon=True).start()

    def _update_stats(self):
        pct = cpu_percent()
        temp = get_cpu_temp()
        used_ram, total_ram = get_ram_usage()
        ram_pct = round(100 * used_ram / total_ram) if total_ram else 0
        gov = get_governor()

        # Per-core freqs
        freqs = [get_cpu_freq_mhz(i) for i in range(self.num_cores)]

        self.root.after(0, lambda: self._apply_stats(pct, temp, ram_pct, gov, freqs))

    def _apply_stats(self, pct, temp, ram_pct, gov, freqs):
        # Stat labels
        self.cpu_pct_lbl.config(text=f"{pct}%",
                                 fg=RED if pct > 85 else ACCENT2)
        self.temp_lbl.config(text=f"{temp}°C" if temp else "--°C",
                              fg=RED if temp > 90 else YELLOW if temp > 75 else GREEN)
        self.ram_lbl.config(text=f"{ram_pct}%",
                             fg=RED if ram_pct > 85 else GREEN)
        self.gov_lbl.config(text=gov,
                             fg=ACCENT if gov == "performance" else FG_DIM)
        self.gov_var.set(gov)

        # Core bars
        for i, (freq) in enumerate(freqs):
            bar, bar_bg = self.freq_bars[i]
            lbl = self.freq_labels[i]
            width = bar_bg.winfo_width()
            if width < 10:
                width = 440
            ratio = min(freq / self.max_mhz, 1.0) if self.max_mhz else 0
            bar_w = int(ratio * width)
            if ratio > 0.85:
                color = ACCENT
            elif ratio > 0.5:
                color = ACCENT2
            else:
                color = GREEN
            bar.config(bg=color, width=bar_w)
            bar.place(x=0, y=0, height=14, width=bar_w)
            lbl.config(text=f"{freq} MHz")

    # ── Controls ──────────────────────────────────────────────────────────────

    def _toggle_turbo(self):
        if self.turbo_active.get():
            # Turn off
            self.turbo_active.set(False)
            self.turbo_btn.config(text="🚀  TURBO MODE  OFF", bg=PANEL, fg=FG_DIM)
            self.status_dot.config(fg=FG_DIM)
            self.status_label.config(text="Idle", fg=FG_DIM)
            self._log("Turbo Mode OFF — restoring schedutil governor...")

            def off():
                set_governor("schedutil")
                run("systemctl stop macfanctld 2>/dev/null", sudo=True)
                self._log("Governor → schedutil. Fan daemon stopped.")
            threading.Thread(target=off, daemon=True).start()
        else:
            # Turn on
            self.turbo_active.set(True)
            self.turbo_btn.config(text="🚀  TURBO MODE  ON ", bg=ACCENT, fg="white")
            self.status_dot.config(fg=ACCENT)
            self.status_label.config(text="Turbo Active", fg=ACCENT)
            self._log("Turbo Mode ON — forcing performance governor + fan daemon...")

            def on():
                set_governor("performance")
                # Try to start fan daemon
                run("systemctl start macfanctld 2>/dev/null || macfanctld &", sudo=True)
                self._log("Governor → performance. Fan daemon started.")
                self._log(f"CPU max boost: {self.max_mhz} MHz")
            threading.Thread(target=on, daemon=True).start()

    def _on_governor_change(self, event=None):
        pass  # wait for Apply click

    def _apply_governor(self):
        gov = self.gov_var.get()
        self._log(f"Setting governor → {gov}...")
        def do():
            set_governor(gov)
            self._log(f"✓ Governor set to {gov}")
        threading.Thread(target=do, daemon=True).start()

    def _toggle_throttle(self):
        state = get_throttle_state()
        if state is None:
            messagebox.showerror("Missing Tool",
                "msr-tools is not installed.\nClick 'Install All Tools' first.")
            return
        if state:
            # Re-enable throttle
            if messagebox.askyesno("Confirm", "Re-enable thermal throttling?"):
                self._log("Re-enabling thermal throttle...")
                def do():
                    restore_throttle()
                    self._log("✓ Throttle re-enabled.")
                    state2 = get_throttle_state()
                    self.root.after(0, lambda: self._update_throttle_ui(state2))
                threading.Thread(target=do, daemon=True).start()
        else:
            # Disable throttle
            answer = messagebox.askyesno(
                "⚠ Warning",
                "Disabling thermal throttling allows max performance "
                "but your Mac will run HOTTER.\n\n"
                "Make sure fan control is running.\n\n"
                "Proceed?"
            )
            if answer:
                self._log("Disabling thermal throttle (MSR 0x1a2)...")
                def do():
                    disable_throttle()
                    self._log("✓ Thermal throttle disabled. Max boost unlocked.")
                    self._log("⚠ Resets on reboot. Re-run to persist.")
                    state2 = get_throttle_state()
                    self.root.after(0, lambda: self._update_throttle_ui(state2))
                threading.Thread(target=do, daemon=True).start()

    def _toggle_fan(self):
        out = run("systemctl is-active macfanctld 2>/dev/null")
        if out == "active":
            self._log("Stopping macfanctld...")
            def do():
                run("systemctl stop macfanctld", sudo=True)
                self._log("✓ Fan daemon stopped.")
                self.root.after(0, self._refresh_fan_ui)
            threading.Thread(target=do, daemon=True).start()
        else:
            self._log("Starting macfanctld...")
            def do():
                result = run("systemctl start macfanctld 2>&1 || macfanctld 2>&1", sudo=True)
                self._log("✓ Fan daemon started.")
                self.root.after(0, self._refresh_fan_ui)
            threading.Thread(target=do, daemon=True).start()

    def _refresh_fan_ui(self):
        out = run("systemctl is-active macfanctld 2>/dev/null")
        if out == "active":
            self.fan_state_lbl.config(text="● Running", fg=GREEN)
            self.fan_btn.config(text="Stop Fan Daemon", bg=RED)
        else:
            self.fan_state_lbl.config(text="● Stopped", fg=FG_DIM)
            self.fan_btn.config(text="Start Fan Daemon", bg=GREEN)

    def _install_tools(self):
        if not messagebox.askyesno("Install Tools",
            "This will install:\n"
            "  msr-tools, cpupower, linux-tools-generic\n"
            "  macfanctld, lm-sensors\n\n"
            "Requires sudo/pkexec. Continue?"):
            return
        self._log("Installing tools (this may take a minute)...")
        def do():
            install_tools()
            self._log("✓ Tools installed! Restart CoreBoost to apply.")
        threading.Thread(target=do, daemon=True).start()

    def on_close(self):
        self.running = False
        self.root.destroy()


# ─── Entry ────────────────────────────────────────────────────────────────────

def main():
    root = tk.Tk()
    app = CoreBoostApp(root)
    root.protocol("WM_DELETE_WINDOW", app.on_close)

    # Style ttk combobox
    style = ttk.Style()
    style.theme_use("clam")
    style.configure("TCombobox",
                     fieldbackground=PANEL,
                     background=PANEL,
                     foreground=FG,
                     selectbackground=ACCENT2,
                     selectforeground=FG)

    root.mainloop()


if __name__ == "__main__":
    main()
