import AppKit
import Darwin
import Foundation

final class SafeDesktopManager {
    private static let lock = NSLock()
    
    // Secure user-private cache directory (prevents symlink attacks in /tmp)
    private static let stateFileURL: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let appDir = base.appendingPathComponent("com.local.showdesktop", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: [
            .posixPermissions: 0o700
        ])
        return appDir.appendingPathComponent("state.v2.txt")
    }()

    private static let lockFileURL: URL = {
        return stateFileURL.deletingLastPathComponent().appendingPathComponent("daemon.lock")
    }()

    // POSIX flock for sub-millisecond singleton daemon check (0 subshell forks)
    static func acquireDaemonLock() -> Bool {
        let fd = open(lockFileURL.path, O_CREAT | O_RDWR, 0o600)
        guard fd >= 0 else { return false }
        if flock(fd, LOCK_EX | LOCK_NB) != 0 {
            close(fd)
            return false
        }
        return true
    }

    static func isDaemonActive() -> Bool {
        let fd = open(lockFileURL.path, O_CREAT | O_RDWR, 0o600)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        if flock(fd, LOCK_EX | LOCK_NB) == 0 {
            flock(fd, LOCK_UN)
            return false
        }
        return true
    }

    // Single-pass atomic state capture
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

        guard !targetApps.isEmpty else {
            finderApp?.activate(options: [.activateIgnoringOtherApps])
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

        finderApp?.activate(options: [.activateIgnoringOtherApps])

        for app in targetApps {
            app.hide()
        }
    }

    static func restoreSavedApps() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard FileManager.default.fileExists(atPath: stateFileURL.path) else { return false }
        defer { try? FileManager.default.removeItem(at: stateFileURL) }

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

        frontToActivate?.activate(options: [.activateIgnoringOtherApps])
        return true
    }

    static func toggle() {
        if FileManager.default.fileExists(atPath: stateFileURL.path) {
            _ = restoreSavedApps()
        } else {
            hideAndSaveState()
        }
    }
}

final class DesktopWatcher: NSObject {
    func start() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(onActivation(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func onActivation(_ notif: Notification) {
        guard let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier == "com.apple.finder" else { return }
        SafeDesktopManager.hideAndSaveState()
    }
}

func ensureDaemonAlive() {
    if !SafeDesktopManager.isDaemonActive() {
        let binaryPath = "/Users/andrew/Documents/antigravity/splendid-volta/show_desktop"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["--daemon"]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }
}

let args = CommandLine.arguments

if args.contains("--daemon") {
    guard SafeDesktopManager.acquireDaemonLock() else {
        exit(0)
    }
    let watcher = DesktopWatcher()
    watcher.start()
    CFRunLoopRun()
} else {
    SafeDesktopManager.toggle()
    ensureDaemonAlive()
}
