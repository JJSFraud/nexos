'use strict';

// =============================================================================
// NexOS Shell — Electron Main Process
// =============================================================================

const {
    app,
    BrowserWindow,
    globalShortcut,
    ipcMain,
    Tray,
    Menu,
    nativeImage,
    screen,
    shell,
    dialog,
    Notification,
} = require('electron');

const path   = require('path');
const fs     = require('fs');
const { execFile, exec, spawn } = require('child_process');
const os     = require('os');

// ---------------------------------------------------------------------------
// Paths
// ---------------------------------------------------------------------------
const NEXOS_ROOT    = path.resolve(__dirname, '..');
const CONFIG_PATH   = path.join(NEXOS_ROOT, 'config', 'nexos.conf');
const SCRIPTS_DIR   = path.join(NEXOS_ROOT, 'scripts');
const SHELL_DIR     = __dirname;

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
let mainWindow     = null;
let settingsWindow = null;
let tray           = null;
let config         = {};
let openWindows    = [];   // track windows opened by the shell
let gamingModeActive = false;

// ---------------------------------------------------------------------------
// Config helpers
// ---------------------------------------------------------------------------
function loadConfig() {
    try {
        const raw = fs.readFileSync(CONFIG_PATH, 'utf-8');
        config = JSON.parse(raw);
    } catch (e) {
        console.warn('[NexOS] Could not load config, using defaults:', e.message);
        config = {
            appearance: { theme: 'blue', taskbarStyle: 'win12' },
            performance: { gamingMode: false, cpuGovernor: 'schedutil' },
            compatibility: { wineEnabled: true, waydroidEnabled: false },
        };
    }
    return config;
}

function saveConfig() {
    try {
        fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2), 'utf-8');
    } catch (e) {
        console.error('[NexOS] Failed to save config:', e.message);
    }
}

function getNestedConfig(obj, keyPath) {
    const parts = keyPath.split('.');
    let cur = obj;
    for (const p of parts) {
        if (cur == null || typeof cur !== 'object') return undefined;
        cur = cur[p];
    }
    return cur;
}

function setNestedConfig(obj, keyPath, value) {
    const parts = keyPath.split('.');
    let cur = obj;
    for (let i = 0; i < parts.length - 1; i++) {
        if (cur[parts[i]] == null || typeof cur[parts[i]] !== 'object') {
            cur[parts[i]] = {};
        }
        cur = cur[parts[i]];
    }
    cur[parts[parts.length - 1]] = value;
}

// ---------------------------------------------------------------------------
// Helper: run a shell script with sudo
// ---------------------------------------------------------------------------
function runScript(scriptName, args = []) {
    return new Promise((resolve, reject) => {
        const scriptPath = path.join(SCRIPTS_DIR, scriptName);
        const cmd = process.platform === 'linux' ? 'bash' : 'cmd';
        const cmdArgs = process.platform === 'linux'
            ? [scriptPath, ...args]
            : ['/c', scriptPath, ...args];

        execFile(cmd, cmdArgs, { timeout: 30_000 }, (err, stdout, stderr) => {
            if (err) {
                console.error(`[NexOS] Script error (${scriptName}):`, stderr || err.message);
                reject(new Error(stderr || err.message));
            } else {
                resolve(stdout.trim());
            }
        });
    });
}

// ---------------------------------------------------------------------------
// Helper: run script with pkexec / sudo
// ---------------------------------------------------------------------------
function runScriptElevated(scriptName, args = []) {
    return new Promise((resolve, reject) => {
        const scriptPath = path.join(SCRIPTS_DIR, scriptName);
        const spawned = spawn('pkexec', ['bash', scriptPath, ...args], {
            stdio: ['pipe', 'pipe', 'pipe'],
        });
        let stdout = '';
        let stderr = '';
        spawned.stdout.on('data', d => { stdout += d; });
        spawned.stderr.on('data', d => { stderr += d; });
        spawned.on('close', code => {
            if (code === 0) resolve(stdout.trim());
            else reject(new Error(stderr.trim() || `Exit code ${code}`));
        });
        spawned.on('error', reject);
    });
}

// ---------------------------------------------------------------------------
// System Info collector
// ---------------------------------------------------------------------------
async function collectSystemInfo() {
    const info = {
        hostname:      os.hostname(),
        platform:      os.platform(),
        arch:          os.arch(),
        kernelVersion: os.release(),
        nexosVersion:  '0.1.0-demo',
        uptime:        os.uptime(),
        cpu: {
            model:   os.cpus()[0]?.model || 'Unknown',
            cores:   os.cpus().length,
            usagePercent: 0,
        },
        ram: {
            totalMB: Math.round(os.totalmem() / 1024 / 1024),
            freeMB:  Math.round(os.freemem() / 1024 / 1024),
            usedMB:  0,
        },
        gpu: { gpu: 'Unknown', type: 'none', driver: 'none' },
    };

    info.ram.usedMB = info.ram.totalMB - info.ram.freeMB;

    // CPU usage via /proc/stat on Linux
    if (process.platform === 'linux') {
        try {
            const stat1 = fs.readFileSync('/proc/stat', 'utf-8').split('\n')[0].split(' ').slice(1).map(Number);
            await new Promise(r => setTimeout(r, 200));
            const stat2 = fs.readFileSync('/proc/stat', 'utf-8').split('\n')[0].split(' ').slice(1).map(Number);
            const idle1 = stat1[3], total1 = stat1.reduce((a, b) => a + b, 0);
            const idle2 = stat2[3], total2 = stat2.reduce((a, b) => a + b, 0);
            const idleDiff  = idle2  - idle1;
            const totalDiff = total2 - total1;
            info.cpu.usagePercent = Math.round((1 - idleDiff / totalDiff) * 100);
        } catch (_) {}
    }

    // GPU via detect-gpu.sh
    try {
        const gpuJson = await runScript('detect-gpu.sh');
        info.gpu = JSON.parse(gpuJson);
    } catch (_) {}

    return info;
}

// ---------------------------------------------------------------------------
// Create the main shell window
// ---------------------------------------------------------------------------
function createMainWindow() {
    const { width, height } = screen.getPrimaryDisplay().workAreaSize;

    mainWindow = new BrowserWindow({
        width,
        height,
        x: 0,
        y: 0,
        frame: false,
        transparent: true,
        resizable: false,
        movable: false,
        fullscreen: true,
        alwaysOnBottom: true,   // acts as desktop
        skipTaskbar: true,
        webPreferences: {
            preload:            path.join(SHELL_DIR, 'preload.js'),
            contextIsolation:   true,
            nodeIntegration:    false,
            sandbox:            false,
            backgroundThrottling: false,
        },
    });

    mainWindow.loadFile(path.join(SHELL_DIR, 'index.html'));
    mainWindow.setIgnoreMouseEvents(false);

    mainWindow.on('closed', () => {
        mainWindow = null;
    });

    // In dev, uncomment to open DevTools:
    // mainWindow.webContents.openDevTools({ mode: 'detach' });
}

// ---------------------------------------------------------------------------
// Create the settings window
// ---------------------------------------------------------------------------
function createSettingsWindow() {
    if (settingsWindow && !settingsWindow.isDestroyed()) {
        settingsWindow.focus();
        return;
    }

    settingsWindow = new BrowserWindow({
        width:  960,
        height: 680,
        title:  'NexOS Settings',
        frame:  false,
        transparent: true,
        resizable: true,
        center: true,
        skipTaskbar: false,
        webPreferences: {
            preload:          path.join(SHELL_DIR, 'preload.js'),
            contextIsolation: true,
            nodeIntegration:  false,
            sandbox:          false,
        },
    });

    settingsWindow.loadFile(path.join(SHELL_DIR, 'settings.html'));

    settingsWindow.on('closed', () => {
        settingsWindow = null;
    });
}

// ---------------------------------------------------------------------------
// System Tray
// ---------------------------------------------------------------------------
function createTray() {
    // Create a minimal icon programmatically if no file exists
    const iconPath = path.join(SHELL_DIR, 'assets', 'icon.png');
    let trayIcon;
    if (fs.existsSync(iconPath)) {
        trayIcon = nativeImage.createFromPath(iconPath).resize({ width: 22, height: 22 });
    } else {
        // 1×1 transparent PNG fallback
        trayIcon = nativeImage.createEmpty();
    }

    tray = new Tray(trayIcon);
    tray.setToolTip('NexOS Shell');

    const contextMenu = Menu.buildFromTemplate([
        { label: 'NexOS Shell v0.1.0-demo', enabled: false },
        { type: 'separator' },
        { label: 'Open Settings',    click: createSettingsWindow },
        { label: 'Open Launcher',    click: () => sendShellEvent('open-launcher') },
        { type: 'separator' },
        {
            label: `Gaming Mode: ${gamingModeActive ? 'ON' : 'OFF'}`,
            click: () => toggleGamingMode(!gamingModeActive),
        },
        { type: 'separator' },
        { label: 'Restart Shell',    click: () => { app.relaunch(); app.exit(0); } },
        { label: 'Quit NexOS Shell', click: () => app.quit() },
    ]);

    tray.setContextMenu(contextMenu);
    tray.on('click', () => sendShellEvent('open-launcher'));
}

// ---------------------------------------------------------------------------
// Register global shortcuts
// ---------------------------------------------------------------------------
function registerShortcuts() {
    // Super/Meta key — open launcher
    globalShortcut.register('Super', () => sendShellEvent('open-launcher'));
    // Win+D — show desktop
    globalShortcut.register('Super+D', () => sendShellEvent('show-desktop'));
    // Win+E — file manager
    globalShortcut.register('Super+E', () => sendShellEvent('open-files'));
    // Win+L — lock
    globalShortcut.register('Super+L', () => sendShellEvent('lock-screen'));
    // Win+S — settings
    globalShortcut.register('Super+S', createSettingsWindow);
    // Win+T — terminal
    globalShortcut.register('Super+T', () => launchApp({ path: 'xterm' }));
    // Alt+F4 — close focused window (pass-through; handled in renderer)
    // Ctrl+Alt+T — terminal
    globalShortcut.register('Control+Alt+T', () => launchApp({ path: 'xterm' }));
    // Print screen
    globalShortcut.register('PrintScreen', () => sendShellEvent('screenshot'));
    // F11 — fullscreen toggle for foreground app
    // (handled by individual apps)
}

// ---------------------------------------------------------------------------
// IPC Helpers
// ---------------------------------------------------------------------------
function sendShellEvent(action, payload = {}) {
    if (mainWindow && !mainWindow.isDestroyed()) {
        mainWindow.webContents.send('shell-event', { action, ...payload });
    }
}

function broadcastConfigChange(key, value) {
    const data = { key, value };
    if (mainWindow    && !mainWindow.isDestroyed())    mainWindow.webContents.send('config-changed', data);
    if (settingsWindow && !settingsWindow.isDestroyed()) settingsWindow.webContents.send('config-changed', data);
}

// ---------------------------------------------------------------------------
// Gaming Mode
// ---------------------------------------------------------------------------
async function toggleGamingMode(enabled) {
    gamingModeActive = enabled;
    try {
        const result = await runScriptElevated('gaming-mode.sh', [enabled ? 'on' : 'off']);
        console.log('[NexOS] Gaming mode result:', result);
        setNestedConfig(config, 'performance.gamingMode', enabled);
        saveConfig();
        broadcastConfigChange('performance.gamingMode', enabled);
        return { success: true, message: result };
    } catch (e) {
        console.error('[NexOS] Gaming mode failed:', e.message);
        return { success: false, error: e.message };
    }
}

// ---------------------------------------------------------------------------
// App launcher
// ---------------------------------------------------------------------------
function launchApp({ path: appPath, opts = {} }) {
    return new Promise((resolve, reject) => {
        const args = opts.args || [];
        const env  = { ...process.env, ...(opts.env || {}) };

        const child = spawn(appPath, args, {
            detached: true,
            stdio:    'ignore',
            env,
        });
        child.unref();

        child.on('error', err => {
            console.error(`[NexOS] Failed to launch '${appPath}':`, err.message);
            reject(err);
        });

        // Track the window
        const winEntry = {
            id:    child.pid,
            title: path.basename(appPath),
            icon:  '',
            pid:   child.pid,
        };
        openWindows.push(winEntry);

        child.on('close', () => {
            openWindows = openWindows.filter(w => w.pid !== child.pid);
            if (mainWindow && !mainWindow.isDestroyed()) {
                mainWindow.webContents.send('windows-changed', { windows: openWindows });
            }
        });

        if (mainWindow && !mainWindow.isDestroyed()) {
            mainWindow.webContents.send('windows-changed', { windows: openWindows });
        }

        resolve({ pid: child.pid });
    });
}

// ---------------------------------------------------------------------------
// IPC handlers
// ---------------------------------------------------------------------------
function registerIpcHandlers() {

    // ---- launch-app ----
    ipcMain.handle('launch-app', async (_e, { path: appPath, opts }) => {
        try {
            return await launchApp({ path: appPath, opts });
        } catch (err) {
            return { error: err.message };
        }
    });

    // ---- launch-exe (via Wine) ----
    ipcMain.handle('launch-exe', async (_e, { path: exePath }) => {
        try {
            const result = await runScript('launch-exe.sh', [exePath]);
            return { success: true, output: result };
        } catch (err) {
            return { success: false, error: err.message };
        }
    });

    // ---- launch-apk (via Waydroid) ----
    ipcMain.handle('launch-apk', async (_e, { path: apkPath }) => {
        try {
            const result = await runScript('launch-apk.sh', [apkPath]);
            return { success: true, output: result };
        } catch (err) {
            return { success: false, error: err.message };
        }
    });

    // ---- launch-dmg (via Darling) ----
    ipcMain.handle('launch-dmg', async (_e, { path: dmgPath }) => {
        try {
            const result = await runScript('launch-dmg.sh', [dmgPath]);
            return { success: true, output: result };
        } catch (err) {
            return { success: false, error: err.message };
        }
    });

    // ---- get-system-info ----
    ipcMain.handle('get-system-info', async () => {
        try {
            return await collectSystemInfo();
        } catch (err) {
            return { error: err.message };
        }
    });

    // ---- get-open-windows ----
    ipcMain.handle('get-open-windows', () => {
        return openWindows;
    });

    // ---- toggle-gaming-mode ----
    ipcMain.handle('toggle-gaming-mode', async (_e, { enabled }) => {
        return await toggleGamingMode(enabled);
    });

    // ---- open-settings ----
    ipcMain.handle('open-settings', () => {
        createSettingsWindow();
        return { success: true };
    });

    // ---- set-wallpaper ----
    ipcMain.handle('set-wallpaper', (_e, { path: wallpaperPath }) => {
        setNestedConfig(config, 'appearance.wallpaper.imagePath', wallpaperPath);
        setNestedConfig(config, 'appearance.wallpaper.type', 'image');
        saveConfig();

        // Tell nitrogen to update wallpaper
        exec(`nitrogen --set-auto "${wallpaperPath}"`, (err) => {
            if (err) console.warn('[NexOS] nitrogen error:', err.message);
        });

        if (mainWindow && !mainWindow.isDestroyed()) {
            mainWindow.webContents.send('wallpaper-changed', { path: wallpaperPath });
        }
        return { success: true };
    });

    // ---- set-theme ----
    ipcMain.handle('set-theme', (_e, { theme }) => {
        setNestedConfig(config, 'appearance.theme', theme);
        saveConfig();
        broadcastConfigChange('appearance.theme', theme);
        if (mainWindow && !mainWindow.isDestroyed()) {
            mainWindow.webContents.send('theme-changed', { theme });
        }
        return { success: true };
    });

    // ---- set-taskbar-style ----
    ipcMain.handle('set-taskbar-style', (_e, { style }) => {
        setNestedConfig(config, 'appearance.taskbarStyle', style);
        saveConfig();
        broadcastConfigChange('appearance.taskbarStyle', style);
        return { success: true };
    });

    // ---- get-config ----
    ipcMain.handle('get-config', () => config);

    // ---- set-config ----
    ipcMain.handle('set-config', (_e, { key, value }) => {
        setNestedConfig(config, key, value);
        saveConfig();
        broadcastConfigChange(key, value);
        return { success: true };
    });

    // ---- show-notification ----
    ipcMain.handle('show-notification', (_e, { title, body, type }) => {
        if (Notification.isSupported()) {
            new Notification({ title, body, urgency: type === 'error' ? 'critical' : 'low' }).show();
        }
        // Also forward to renderer notification system
        if (mainWindow && !mainWindow.isDestroyed()) {
            mainWindow.webContents.send('notification', {
                id:    Date.now(),
                title,
                body,
                type,
            });
        }
        return { success: true };
    });
}

// ---------------------------------------------------------------------------
// App lifecycle
// ---------------------------------------------------------------------------
app.whenReady().then(() => {
    loadConfig();
    createMainWindow();
    createTray();
    registerShortcuts();
    registerIpcHandlers();

    app.on('activate', () => {
        if (BrowserWindow.getAllWindows().length === 0) createMainWindow();
    });
});

app.on('window-all-closed', () => {
    // On Linux, keep the app running (shell must always be active)
    if (process.platform !== 'darwin') {
        // If main window closed unexpectedly, relaunch it
        if (!mainWindow) {
            setTimeout(createMainWindow, 500);
        }
    }
});

app.on('will-quit', () => {
    globalShortcut.unregisterAll();
});

// Prevent multiple instances
const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
    app.quit();
} else {
    app.on('second-instance', () => {
        if (mainWindow) {
            if (mainWindow.isMinimized()) mainWindow.restore();
            mainWindow.focus();
        }
    });
}

// Security: prevent navigation to external URLs in main window
app.on('web-contents-created', (_event, contents) => {
    contents.on('will-navigate', (event, url) => {
        const parsed = new URL(url);
        if (parsed.origin !== 'null' && !url.startsWith('file://')) {
            event.preventDefault();
            shell.openExternal(url);
        }
    });
    contents.setWindowOpenHandler(({ url }) => {
        shell.openExternal(url);
        return { action: 'deny' };
    });
});
