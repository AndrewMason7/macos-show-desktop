import AppKit
import Darwin
import Foundation

final class DesktopManager {
    private static let lock = NSLock()
    
    private static let stateFileURL: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let appDir = base.appendingPathComponent("com.local.showdesktop", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: [
            .posixPermissions: 0o700
        ])
        return appDir.appendingPathComponent("state.v2.txt")
    }()

    static func hasSavedState() -> Bool {
        return FileManager.default.fileExists(atPath: stateFileURL.path)
    }

    private static func setFinderWindowsCollapsed(_ collapsed: Bool) {
        let scriptSource = """
        tell application "Finder"
            try
                set collapsed of every window to \(collapsed ? "true" : "false")
            end try
        end tell
        """
        if let script = NSAppleScript(source: scriptSource) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
        }
    }

    static func hideAndSaveState() {
        lock.lock()
        defer { lock.unlock() }

        var targetApps: [NSRunningApplication] = []
        var frontBundleID: String = ""
        var finderApp: NSRunningApplication?

        let allApps = NSWorkspace.shared.runningApplications
        let activeApp = NSWorkspace.shared.frontmostApplication

        if let active = activeApp, active.bundleIdentifier != "com.apple.finder" {
            frontBundleID = active.bundleIdentifier ?? ""
        }

        for app in allApps {
            guard app.activationPolicy == .regular else { continue }
            if app.bundleIdentifier == "com.apple.finder" {
                finderApp = app
            } else if !app.isHidden {
                targetApps.append(app)
            }
        }

        // Collapse open Finder folder windows so desktop is 100% visible
        setFinderWindowsCollapsed(true)

        guard !targetApps.isEmpty else {
            finderApp?.activate()
            return
        }

        var bundleList: [String] = []
        if !frontBundleID.isEmpty {
            bundleList.append(frontBundleID)
        }
        for app in targetApps {
            if let bID = app.bundleIdentifier, bID != frontBundleID {
                bundleList.append(bID)
            }
        }

        let payload = bundleList.joined(separator: "\n")
        try? payload.write(to: stateFileURL, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: stateFileURL.path)

        finderApp?.activate()

        for app in targetApps {
            app.hide()
        }
    }

    static func restoreSavedApps() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard FileManager.default.fileExists(atPath: stateFileURL.path) else { return false }
        defer { try? FileManager.default.removeItem(at: stateFileURL) }

        // Restore open Finder folder windows
        setFinderWindowsCollapsed(false)

        guard let raw = try? String(contentsOf: stateFileURL, encoding: .utf8) else { return false }
        let validLines = raw.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !validLines.isEmpty else { return false }

        let frontID = validLines[0]
        let targetSet = Set(validLines)

        var frontToActivate: NSRunningApplication?
        let allApps = NSWorkspace.shared.runningApplications

        for app in allApps {
            guard app.activationPolicy == .regular, let bID = app.bundleIdentifier else { continue }
            if targetSet.contains(bID) {
                app.unhide()
                if bID == frontID {
                    frontToActivate = app
                }
            }
        }

        frontToActivate?.activate()
        return true
    }

    static func toggle() {
        if hasSavedState() {
            _ = restoreSavedApps()
        } else {
            hideAndSaveState()
        }
    }
}

DesktopManager.toggle()
