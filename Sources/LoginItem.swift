import AppKit
import ServiceManagement

/// "Open at login", using the system login item list (System Settings › General › Login Items).
enum LoginItem {
    static var status: SMAppService.Status { SMAppService.mainApp.status }

    static var isEnabled: Bool { status == .enabled }

    /// On but waiting for the user to allow it in System Settings.
    static var needsApproval: Bool { status == .requiresApproval }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Login item \(enabled ? "register" : "unregister") failed: \(error)")
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    /// Only offer it for an installed copy, not one running from a DMG, Downloads, or a local build.
    static var isInstalledCopy: Bool {
        let path = Bundle.main.bundlePath
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix("/Applications/") || path.hasPrefix(home + "/Applications/")
    }

    /// Asks once, on the first launch of a version with this feature: a new install or an update.
    static func offerIfNeeded() {
        guard !Preferences.hasOfferedLoginItem, isInstalledCopy else { return }
        Preferences.hasOfferedLoginItem = true
        guard status == .notRegistered || status == .notFound else { return }

        let alert = NSAlert()
        alert.messageText = "Open macOS Audio Renamer at login?"
        alert.informativeText = "It lives in the menu bar and keeps your preferred speaker and mic selected. You can change this later in Settings."
        alert.addButton(withTitle: "Open at Login")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            setEnabled(true)
        }
    }
}
