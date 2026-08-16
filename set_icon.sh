#!/usr/bin/env bash
# Usage: ./set_icon.sh /path/to/custom_image.png (or leave blank to reset to default Desktop icon)

IMAGE_PATH="${1:-/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/DesktopFolderIcon.icns}"

swift - "$IMAGE_PATH" << 'SWIFT_EOF'
import AppKit

let args = CommandLine.arguments
guard args.count > 1 else { exit(1) }
let iconPath = args[1]

let targetApp = "/Users/andrew/Desktop/Show Desktop.app"
let targetScript = "/Users/andrew/Documents/antigravity/splendid-volta/show_desktop.sh"

if let img = NSImage(contentsOfFile: iconPath) {
    NSWorkspace.shared.setIcon(img, forFile: targetScript, options: [])
    NSWorkspace.shared.setIcon(img, forFile: targetApp, options: [])
    print("✅ Custom icon applied to both Show Desktop.app and show_desktop.sh")
} else {
    print("❌ Could not load image from: \(iconPath)")
}
SWIFT_EOF
