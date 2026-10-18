# NexOS 🌌

> A lightweight, beautiful Linux-based operating system — Windows 12 aesthetics meet macOS elegance.

[![Version](https://img.shields.io/badge/version-0.1.0--demo-blue.svg)]()
[![Base](https://img.shields.io/badge/base-Debian%20Bookworm-red.svg)]()
[![License](https://img.shields.io/badge/license-MIT-green.svg)]()
[![Shell](https://img.shields.io/badge/shell-Electron%20%2B%20Openbox-blueviolet.svg)]()

---

## What is NexOS?

NexOS is a custom, lightweight Linux operating system built on a **Debian Bookworm minimal base**. It replaces the traditional desktop environment with a custom **Electron-based shell** that delivers a stunning **Windows 12 + macOS hybrid** aesthetic — complete with glassmorphism panels, fluid animations, and a centered taskbar.

### Key Features

| Feature | Details |
|---------|---------|
| 🎨 **Modern UI** | Windows 12 + macOS hybrid shell with glassmorphism |
| 🪶 **Lightweight** | Targets < 512 MB RAM at idle |
| 🍷 **Wine** | Run Windows .exe and .msi files natively |
| 🤖 **Waydroid** | Run Android .apk apps in a container |
| 🍎 **Darling** | Experimental macOS .dmg support |
| 🎮 **Gaming Mode** | One-click CPU/GPU performance tuning |
| 🎨 **Themes** | Blue, Purple-Blue, Green, Cyan — live switching |
| 🖼️ **Wallpaper** | Image, video wallpaper, or animated gradient |
| ⚙️ **Settings** | Full settings app with sidebar navigation |

---

## Hardware Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **CPU** | 1 GHz x86_64 dual-core | 2+ GHz quad-core |
| **RAM** | 1 GB | 2 GB+ |
| **Storage** | 4 GB | 8 GB+ (20 GB+ for Wine/Waydroid) |
| **GPU** | Any with VESA/VESA support | Dedicated NVIDIA/AMD/Intel with open-source drivers |
| **Display** | 1024×768 | 1920×1080+ |
| **Architecture** | x86_64 (64-bit) only | x86_64 |

> **Note:** Waydroid requires a kernel with binder support (Linux 5.7+). The NexOS ISO ships with a standard Debian bookworm kernel that includes binder.

---

## Project Structure

```
NexOS/
├── build/
│   ├── build-iso.sh          # Main ISO build script (run as root on Linux)
│   ├── install-deps.sh       # Installs build dependencies on host
│   ├── openbox-autostart.sh  # Openbox session startup
│   └── grub.cfg              # GRUB bootloader menu
├── shell/
│   ├── main.js               # Electron main process (IPC, shortcuts, tray)
│   ├── preload.js            # Safe contextBridge IPC API
│   ├── index.html            # Desktop shell UI
│   ├── settings.html         # Full settings application
│   └── package.json          # Electron app manifest
├── config/
│   └── nexos.conf            # JSON master configuration file
├── scripts/
│   ├── gaming-mode.sh        # Gaming mode CPU/GPU tuning
│   ├── detect-gpu.sh         # GPU detection → JSON output
│   ├── launch-exe.sh         # Wine .exe launcher
│   ├── launch-apk.sh         # Waydroid .apk launcher
│   └── launch-dmg.sh         # Darling .dmg launcher
└── README.md
```

---

## Building the ISO

### Prerequisites

You need a **Debian or Ubuntu Linux host** (or **WSL2** on Windows) with root access.

### Step 1 — Install build dependencies

```bash
cd /path/to/NexOS
sudo bash build/install-deps.sh
```

This installs: `debootstrap`, `squashfs-tools`, `xorriso`, `grub-pc-bin`, `grub-efi-amd64-bin`, `live-build`, Node.js 20 LTS, and other utilities.

### Step 2 — Build the ISO

```bash
sudo bash build/build-iso.sh
```

This will:
1. Bootstrap a Debian Bookworm minimal chroot with `debootstrap`
2. Install all packages (Xorg, Openbox, picom, Wine, Waydroid, etc.) inside the chroot
3. Configure LightDM auto-login for user `nexos`
4. Set up the NexOS Electron shell at `/opt/nexos/shell`
5. Configure Wine and Waydroid
6. Compress the filesystem with `mksquashfs` (xz compression)
7. Build a bootable ISO using `grub-mkrescue`

Build time: ~20–45 minutes depending on internet speed and CPU.

Output: `NexOS-0.1.0-demo.iso` in the current directory.

### Step 3 — Flash to USB (optional)

```bash
# Replace /dev/sdX with your USB drive
sudo dd if=NexOS-0.1.0-demo.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Or use **Balena Etcher** (GUI) on Windows/macOS/Linux.

---

## Testing in a Virtual Machine

### VirtualBox

1. Create a new VM: **Type: Linux**, **Version: Debian (64-bit)**
2. RAM: **2048 MB** (minimum 1024 MB)
3. Storage: **8 GB** VDI disk
4. Display → Video Memory: **128 MB**, enable **3D Acceleration**
5. Mount the ISO in the optical drive
6. Boot → select **"NexOS 0.1.0-demo"** from GRUB menu
7. System auto-logs in as `nexos` (password: `nexos`)

### VMware Workstation / Fusion

1. New VM → **Linux → Debian 12.x 64-bit**
2. RAM: **2 GB**, Disk: **8 GB**
3. Use **UEFI firmware** for best compatibility
4. Mount ISO → Power on

> **Tip:** For best performance, enable virtualized hardware 3D acceleration and allocate at least 2 cores.

---

## Default Login

| Username | `nexos` |
|----------|---------|
| Password | `nexos` |
| Sudo | Passwordless (live session style) |

---

## Current Demo Features (v0.1.0-demo)

- ✅ Beautiful Electron desktop shell (Win12 + macOS hybrid)
- ✅ Live clock, system tray (battery, volume, network)
- ✅ App launcher overlay with search and categories
- ✅ Right-click desktop context menu
- ✅ Quick Settings panel (volume, brightness, theme, gaming mode)
- ✅ Color themes: Blue, Purple-Blue, Green, Cyan
- ✅ Taskbar styles: Win12 (bottom centered) / macOS (top bar)
- ✅ Glassmorphism + blur compositor (picom)
- ✅ Notification system
- ✅ Full Settings app (Appearance, Display, Performance, Compatibility, System, About)
- ✅ Gaming Mode (CPU governor + service management)
- ✅ Wine integration (.exe launcher)
- ✅ Waydroid integration (.apk launcher)
- ✅ Darling integration (.dmg launcher, experimental)
- ✅ GPU detection script
- ✅ Video wallpaper support
- ✅ Persistent JSON config (`nexos.conf`)
- ✅ Advanced developer settings panel

---

## Roadmap — v2.0

- [ ] **NexOS App Store** — curated Flatpak/AppImage browser
- [ ] **Custom GRUB theme** — NexOS branded boot screen
- [ ] **Compositor profiles** — power-save, balanced, performance
- [ ] **Multi-monitor support** — per-monitor taskbars
- [ ] **Virtual desktops** — Windows-style workspace switcher
- [ ] **Widget system** — draggable desktop widgets (clock, weather, stats)
- [ ] **NexOS Update Manager** — rolling updates via APT
- [ ] **Wayland session** — sway/hyprland backend option
- [ ] **ARM64 support** — Raspberry Pi 4/5 image
- [ ] **Secure Boot** — signed bootloader
- [ ] **Full Darling support** — macOS app compatibility layer
- [ ] **Custom icon pack** — NexOS Fluent icon theme
- [ ] **Lock screen** — beautiful glassmorphism lock screen
- [ ] **Screen recording** — built-in OBS/wf-recorder integration
- [ ] **NexOS Drive** — cloud sync via rclone

---

## Contributing

NexOS is open to contributions! Areas where help is most welcome:

- Icon and wallpaper art
- Testing on real hardware (especially different GPU brands)
- Wine/Waydroid compatibility testing
- Kernel patches for better gaming performance
- Accessibility improvements

---

## License

MIT License © 2024 NexOS Project

---

> *"NexOS — The OS you always wished existed."*
