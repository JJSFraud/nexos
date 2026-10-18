'use strict';

const { contextBridge, ipcRenderer } = require('electron');

// ============================================================
// NexOS Preload — Safe contextBridge API exposed to renderer
// ============================================================

/**
 * Validates that a string argument is a non-empty string.
 * Prevents passing arbitrary objects over IPC.
 */
function assertString(val, name) {
    if (typeof val !== 'string' || val.trim() === '') {
        throw new TypeError(`nexosAPI: argument '${name}' must be a non-empty string.`);
    }
}

/**
 * Wraps an IPC invoke call with basic error handling.
 */
async function invoke(channel, ...args) {
    try {
        return await ipcRenderer.invoke(channel, ...args);
    } catch (err) {
        console.error(`[nexosAPI] IPC error on channel '${channel}':`, err);
        throw err;
    }
}

contextBridge.exposeInMainWorld('nexosAPI', {
    // ----------------------------------------------------------------
    // App management
    // ----------------------------------------------------------------

    /**
     * Launch an application by executable path or name.
     * @param {string} path  Absolute path to the executable or app name.
     * @param {object} [opts] Optional options: { args: [], env: {} }
     */
    launchApp(path, opts = {}) {
        assertString(path, 'path');
        return invoke('launch-app', { path, opts });
    },

    /**
     * Launch a .exe file through Wine.
     */
    launchExe(path) {
        assertString(path, 'path');
        return invoke('launch-exe', { path });
    },

    /**
     * Install/launch an .apk file through Waydroid.
     */
    launchApk(path) {
        assertString(path, 'path');
        return invoke('launch-apk', { path });
    },

    /**
     * Mount and run a .dmg via Darling.
     */
    launchDmg(path) {
        assertString(path, 'path');
        return invoke('launch-dmg', { path });
    },

    // ----------------------------------------------------------------
    // System info
    // ----------------------------------------------------------------

    /**
     * Returns a promise resolving to system info object:
     * { cpu, ram, gpu, uptime, hostname, kernelVersion, nexosVersion }
     */
    getSystemInfo() {
        return invoke('get-system-info');
    },

    /**
     * Returns a promise resolving to list of running windows:
     * [{ id, title, icon, pid }]
     */
    getOpenWindows() {
        return invoke('get-open-windows');
    },

    // ----------------------------------------------------------------
    // Gaming Mode
    // ----------------------------------------------------------------

    /**
     * Toggle Gaming Mode.
     * @param {boolean} enabled  true = ON, false = OFF.
     */
    toggleGamingMode(enabled) {
        return invoke('toggle-gaming-mode', { enabled: Boolean(enabled) });
    },

    // ----------------------------------------------------------------
    // Settings / appearance
    // ----------------------------------------------------------------

    /** Open the Settings window. */
    openSettings() {
        return invoke('open-settings');
    },

    /**
     * Set desktop wallpaper.
     * @param {string} pathOrUrl  Absolute file path or http(s) URL.
     */
    setWallpaper(pathOrUrl) {
        assertString(pathOrUrl, 'pathOrUrl');
        return invoke('set-wallpaper', { path: pathOrUrl });
    },

    /**
     * Set colour theme.
     * @param {'blue'|'purple-blue'|'green'|'cyan'} theme
     */
    setTheme(theme) {
        assertString(theme, 'theme');
        const valid = ['blue', 'purple-blue', 'green', 'cyan'];
        if (!valid.includes(theme)) throw new RangeError(`Invalid theme. Must be one of: ${valid.join(', ')}`);
        return invoke('set-theme', { theme });
    },

    /**
     * Set taskbar style.
     * @param {'win12'|'mac'} style
     */
    setTaskbarStyle(style) {
        assertString(style, 'style');
        const valid = ['win12', 'mac'];
        if (!valid.includes(style)) throw new RangeError(`Invalid style. Must be one of: ${valid.join(', ')}`);
        return invoke('set-taskbar-style', { style });
    },

    // ----------------------------------------------------------------
    // Config persistence
    // ----------------------------------------------------------------

    /**
     * Read the nexos.conf file.
     */
    getConfig() {
        return invoke('get-config');
    },

    /**
     * Write a key-value pair to nexos.conf.
     * @param {string} key
     * @param {*} value
     */
    setConfig(key, value) {
        assertString(key, 'key');
        return invoke('set-config', { key, value });
    },

    // ----------------------------------------------------------------
    // Notification bridge
    // ----------------------------------------------------------------

    /**
     * Show a native notification.
     * @param {string} title
     * @param {string} body
     * @param {'info'|'warning'|'error'} [type]
     */
    notify(title, body, type = 'info') {
        assertString(title, 'title');
        assertString(body, 'body');
        return invoke('show-notification', { title, body, type });
    },

    // ----------------------------------------------------------------
    // Event listeners (renderer subscribes to main-process events)
    // ----------------------------------------------------------------

    /**
     * Listen for window-focus-change events from the main process.
     * Payload: { windows: [{ id, title, icon, focused }] }
     */
    onWindowsChanged(callback) {
        ipcRenderer.on('windows-changed', (_event, data) => callback(data));
    },

    /**
     * Listen for system tray / shortcut events.
     * Payload: { action: 'open-launcher' | 'toggle-gaming' | ... }
     */
    onShellEvent(callback) {
        ipcRenderer.on('shell-event', (_event, data) => callback(data));
    },

    /**
     * Listen for incoming notifications forwarded by main process.
     * Payload: { title, body, type, id }
     */
    onNotification(callback) {
        ipcRenderer.on('notification', (_event, data) => callback(data));
    },

    /**
     * Listen for wallpaper changes.
     */
    onWallpaperChanged(callback) {
        ipcRenderer.on('wallpaper-changed', (_event, data) => callback(data));
    },

    /**
     * Listen for theme changes.
     */
    onThemeChanged(callback) {
        ipcRenderer.on('theme-changed', (_event, data) => callback(data));
    },

    /**
     * Listen for config changes from settings window.
     */
    onConfigChanged(callback) {
        ipcRenderer.on('config-changed', (_event, data) => callback(data));
    },

    // ----------------------------------------------------------------
    // Utility
    // ----------------------------------------------------------------

    /** Returns the platform string ('linux', 'darwin', 'win32'). */
    platform: process.platform,

    /** NexOS version string. */
    version: '0.1.0-demo',
});
