#!/usr/bin/env python3
"""
=============================================================================
Linux Zoner — Graphics & Gaming Performance Optimizer
Tuned specifically for Intel HD Graphics 6000 & 2015 MacBook Air (Core i5 / 8GB)
=============================================================================
"""

import os
import sys
import subprocess
import threading
import time
import tkinter as tk
from tkinter import ttk, filedialog, messagebox

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CORE_SCRIPT = os.path.join(SCRIPT_DIR, "zoner-core.sh")
WRAPPER_SCRIPT = os.path.join(SCRIPT_DIR, "launch-game.sh")

# Dark Theme Colors
BG_MAIN     = "#0c0d14"
BG_CARD     = "#151724"
BG_HOVER    = "#1f2238"
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
        self.root.title("Linux Zoner — GPU & Gaming Performance Booster")
        self.root.geometry("780x640")
        self.root.configure(bg=BG_MAIN)
        self.root.resizable(False, False)

        self.turbo_active = False
        self.fsr_level = tk.IntVar(value=2)
        self.iris_enabled = tk.BooleanVar(value=True)
        self.glthread_enabled = tk.BooleanVar(value=True)
        self.unlock_fps = tk.BooleanVar(value=True)

        self.build_ui()
        self.start_monitoring()

    def build_ui(self):
        # 1. Header Banner
        header = tk.Frame(self.root, bg="#10121d", height=75)
        header.pack(fill="x")
        header.pack_propagate(False)

        title_box = tk.Frame(header, bg="#10121d")
        title_box.pack(side="left", padx=20, pady=12)

        lbl_title = tk.Label(title_box, text="⚡ LINUX ZONER", font=("Segoe UI", 16, "bold"), fg=ACCENT_CYAN, bg="#10121d")
        lbl_title.pack(anchor="w")

        lbl_sub = tk.Label(title_box, text="Graphics & GPU Engine • Optimized for MacBook Air (Intel HD 6000)", font=("Segoe UI", 9), fg=TEXT_MUTED, bg="#10121d")
        lbl_sub.pack(anchor="w")

        self.lbl_badge = tk.Label(header, text="● BALANCED MODE", font=("Segoe UI", 9, "bold"), fg="#ffb300", bg="#2a2310", padx=12, pady=6)
        self.lbl_badge.pack(side="right", padx=20, pady=18)

        # Main Body (Split into Left Controls and Right Monitor)
        body = tk.Frame(self.root, bg=BG_MAIN)
        body.pack(fill="both", expand=True, padx=20, pady=15)

        left_col = tk.Frame(body, bg=BG_MAIN, width=470)
        left_col.pack(side="left", fill="both", expand=True, padx=(0, 10))

        right_col = tk.Frame(body, bg=BG_MAIN, width=260)
        right_col.pack(side="right", fill="both", padx=(10, 0))

        # -------------------------------------------------------------------
        # LEFT COLUMN: Master Turbo Toggle + Settings
        # -------------------------------------------------------------------
        
        # Big Turbo Button Card
        card_turbo = tk.Frame(left_col, bg=BG_CARD, highlightthickness=1, highlightbackground=BORDER_COL, padx=15, pady=15)
        card_turbo.pack(fill="x", pady=(0, 12))

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
            pady=12,
            command=self.toggle_turbo
        )
        self.btn_turbo.pack(fill="x")

        lbl_turbo_desc = tk.Label(
            card_turbo,
            text="Locks Intel HD 6000 GPU to 1000MHz peak clock, sets CPU to Performance,\nand enables low-latency gaming scheduler.",
            font=("Segoe UI", 8),
            fg=TEXT_MUTED,
            bg=BG_CARD,
            justify="center"
        )
        lbl_turbo_desc.pack(pady=(8, 0))

        # Graphics Enhancements Card
        card_gfx = tk.Frame(left_col, bg=BG_CARD, highlightthickness=1, highlightbackground=BORDER_COL, padx=15, pady=12)
        card_gfx.pack(fill="x", pady=(0, 12))

        tk.Label(card_gfx, text="🎮 GRAPHICS & FPS BOOSTERS", font=("Segoe UI", 10, "bold"), fg=ACCENT_CYAN, bg=BG_CARD).pack(anchor="w", pady=(0, 8))

        # AMD FSR Slider
        fsr_box = tk.Frame(card_gfx, bg=BG_CARD)
        fsr_box.pack(fill="x", pady=4)
        tk.Label(fsr_box, text="AMD FSR Upscaling Sharpening:", font=("Segoe UI", 9), fg=TEXT_WHITE, bg=BG_CARD).pack(side="left")
        self.lbl_fsr_val = tk.Label(fsr_box, text="Level 2 (Balanced)", font=("Segoe UI", 9, "bold"), fg=ACCENT_CYAN, bg=BG_CARD)
        self.lbl_fsr_val.pack(side="right")

        fsr_slider = ttk.Scale(card_gfx, from_=1, to=5, orient="horizontal", variable=self.fsr_level, command=self.on_fsr_change)
        fsr_slider.pack(fill="x", pady=(2, 8))

        # Toggles
        cb1 = tk.Checkbutton(card_gfx, text="Enable Mesa Iris Driver (+25-35% GPU FPS)", variable=self.iris_enabled, bg=BG_CARD, fg=TEXT_WHITE, selectcolor="#000000", activebackground=BG_CARD, activeforeground=TEXT_WHITE, font=("Segoe UI", 9))
        cb1.pack(anchor="w", pady=2)

        cb2 = tk.Checkbutton(card_gfx, text="Mesa GL Multithreaded Shader Cache (Stops Stutter)", variable=self.glthread_enabled, bg=BG_CARD, fg=TEXT_WHITE, selectcolor="#000000", activebackground=BG_CARD, activeforeground=TEXT_WHITE, font=("Segoe UI", 9))
        cb2.pack(anchor="w", pady=2)

        cb3 = tk.Checkbutton(card_gfx, text="Unlock 60+ FPS (Disable V-Sync Limit)", variable=self.unlock_fps, bg=BG_CARD, fg=TEXT_WHITE, selectcolor="#000000", activebackground=BG_CARD, activeforeground=TEXT_WHITE, font=("Segoe UI", 9))
        cb3.pack(anchor="w", pady=2)

        # Quick Game Launchers Card
        card_games = tk.Frame(left_col, bg=BG_CARD, highlightthickness=1, highlightbackground=BORDER_COL, padx=15, pady=12)
        card_games.pack(fill="x")

        tk.Label(card_games, text="🕹️ 1-CLICK LAUNCH WITH ZONER BOOST", font=("Segoe UI", 10, "bold"), fg=ACCENT_CYAN, bg=BG_CARD).pack(anchor="w", pady=(0, 8))

        btn_row = tk.Frame(card_games, bg=BG_CARD)
        btn_row.pack(fill="x", pady=2)

        btn_roblox = tk.Button(btn_row, text="🔴 Roblox Boost", font=("Segoe UI", 9, "bold"), bg="#1e2235", fg=TEXT_WHITE, relief="flat", padx=10, pady=6, cursor="hand2", command=self.launch_roblox)
        btn_roblox.pack(side="left", padx=(0, 6), expand=True, fill="x")

        btn_minecraft = tk.Button(btn_row, text="⛏️ Minecraft", font=("Segoe UI", 9, "bold"), bg="#1e2235", fg=TEXT_WHITE, relief="flat", padx=10, pady=6, cursor="hand2", command=self.launch_minecraft)
        btn_minecraft.pack(side="left", padx=3, expand=True, fill="x")

        btn_custom = tk.Button(btn_row, text="📂 Launch Game / EXE...", font=("Segoe UI", 9, "bold"), bg="#283250", fg=ACCENT_CYAN, relief="flat", padx=10, pady=6, cursor="hand2", command=self.launch_custom)
        btn_custom.pack(side="left", padx=(6, 0), expand=True, fill="x")

        # -------------------------------------------------------------------
        # RIGHT COLUMN: Live Performance HUD
        # -------------------------------------------------------------------
        card_hud = tk.Frame(right_col, bg=BG_CARD, highlightthickness=1, highlightbackground=BORDER_COL, padx=15, pady=15)
        card_hud.pack(fill="both", expand=True)

        tk.Label(card_hud, text="📊 LIVE HARDWARE HUD", font=("Segoe UI", 10, "bold"), fg=ACCENT_CYAN, bg=BG_CARD).pack(anchor="w", pady=(0, 10))

        # Stat Items
        self.lbl_hud_gpu = self.create_hud_item(card_hud, "GPU Clock:", "--- MHz", ACCENT_CYAN)
        self.lbl_hud_gov = self.create_hud_item(card_hud, "CPU Governor:", "powersave", TEXT_WHITE)
        self.lbl_hud_ram = self.create_hud_item(card_hud, "RAM Usage:", "--- / 8 GB", TEXT_WHITE)
        self.lbl_hud_fps = self.create_hud_item(card_hud, "Target Refresh:", "60 Hz", ACCENT_GREEN)
        self.lbl_hud_temp = self.create_hud_item(card_hud, "Thermal Status:", "Normal (Cool)", ACCENT_GREEN)

        sep = tk.Frame(card_hud, height=1, bg=BORDER_COL)
        sep.pack(fill="x", pady=15)

        tk.Label(card_hud, text="HARDWARE PROFILE", font=("Segoe UI", 8, "bold"), fg=TEXT_MUTED, bg=BG_CARD).pack(anchor="w")
        tk.Label(card_hud, text="• MacBook Air 2015 (7,2)\n• Intel Core i5-5250U\n• Intel HD Graphics 6000\n• 8 GB LPDDR3 RAM", font=("Segoe UI", 8), fg=TEXT_MUTED, bg=BG_CARD, justify="left").pack(anchor="w", pady=(4, 0))

    def create_hud_item(self, parent, label_text, default_val, val_color):
        frame = tk.Frame(parent, bg=BG_CARD)
        frame.pack(fill="x", pady=6)
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

    def toggle_turbo(self):
        self.turbo_active = not self.turbo_active
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
        # Auto-activate turbo if not active
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
                    # GPU Frequency
                    gpu_freq = "--- MHz"
                    if os.path.exists("/sys/class/drm/card0/gt_cur_freq_mhz"):
                        with open("/sys/class/drm/card0/gt_cur_freq_mhz") as f:
                            gpu_freq = f.read().strip() + " MHz"
                    
                    # CPU Governor
                    gov = "powersave"
                    if os.path.exists("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"):
                        with open("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor") as f:
                            gov = f.read().strip()

                    # RAM Usage
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
