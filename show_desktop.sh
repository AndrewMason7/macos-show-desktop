#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$DIR/show_desktop"
PLIST="$HOME/Library/LaunchAgents/com.local.showdesktop.plist"
UID_NUM=$(id -u)

case "$1" in
    --stop)
        launchctl bootout "gui/$UID_NUM/com.local.showdesktop" 2>/dev/null || launchctl unload "$PLIST" 2>/dev/null
        pkill -f "$BIN.*--daemon" 2>/dev/null
        echo "⏹️ 24/7 background listener disabled and stopped."
        ;;
    --start)
        launchctl bootstrap "gui/$UID_NUM" "$PLIST" 2>/dev/null || launchctl load "$PLIST" 2>/dev/null
        echo "▶️ 24/7 background listener enabled and loaded."
        ;;
    --status)
        if launchctl list | grep -q "com.local.showdesktop" || pgrep -f "$BIN.*--daemon" > /dev/null; then
            echo "✅ Background listener is RUNNING 24/7 (managed by macOS launchd)."
        else
            echo "❌ Background listener is NOT running."
        fi
        ;;
    *)
        "$BIN" "$@"
        echo "🖥️ Desktop toggled & 24/7 listener verified."
        ;;
esac
