# macOS Show Desktop 🖥️

A lightning-fast, native macOS utility to instantly toggle and reveal your desktop, complete with state persistence, wallpaper click-to-toggle, and a desktop shortcut application.

## ✨ Features

- ⚡ **Sub-Millisecond Performance**: Written in native Swift using AppKit APIs—no slow AppleScript IPC lags or shell forks.
- 🔄 **Two-Way Toggle & Undo**: Hiding all open applications snapshots their exact coordinates and spaces. Running it again restores every window to its exact original position and refocuses your active app.
- 🖱️ **Wallpaper Click Integration**: Click anywhere on your desktop wallpaper to reveal the desktop, and click again to restore.
- 🔒 **Hardened Security**: Thread-safe with `NSLock`, user-isolated cache storage (`0700`), and POSIX advisory file locking (`flock`).
- 🚀 **Desktop Shortcut (`.app`)**: Ready-to-click `.app` shortcut placed right on your desktop with native icons.
- ⏰ **24/7 Background Daemon**: Managed via macOS `launchd` LaunchAgent.

## 📦 Components

- `ShowDesktop.swift`: Core native Swift engine and background daemon.
- `show_desktop.sh`: CLI controller with `--start`, `--stop`, and `--status` options.
- `set_icon.sh`: Utility to apply any custom icon or image to the app and script.
- `Show Desktop.app`: Standalone application bundle on `~/Desktop`.

## 🛠️ Build & Install

```bash
# Build binary and recreate Desktop shortcut:
make

# Install 24/7 background LaunchAgent:
make install
```

## 📜 CLI Usage

```bash
# Toggle desktop (hide or restore):
./show_desktop.sh

# Check background daemon status:
./show_desktop.sh --status

# Stop background daemon:
./show_desktop.sh --stop

# Start background daemon:
./show_desktop.sh --start
```

## 🎨 Custom Icons

```bash
# Apply a custom PNG/ICNS image:
./set_icon.sh /path/to/custom_icon.png

# Reset to default Desktop icon:
./set_icon.sh
```
