import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    let manager = AudioDeviceManager()
    let updater = Updater()
    private var statusMenu: StatusMenuController!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // One copy only, e.g. when an old-style login item and the new one both launch it.
        if let id = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: id)
               .contains(where: { $0 != .current }) {
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        statusMenu = StatusMenuController(manager: manager, updater: updater) { [weak self] in
            self?.showSettings()
        }
        // Let the menu bar item appear first.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { LoginItem.offerIfNeeded() }
    }

    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Audio Renamer Settings"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.isOpaque = false
            window.backgroundColor = .clear

            // Translucent, blurred window background — the same material as menus.
            let background = NSVisualEffectView()
            background.material = .menu
            background.blendingMode = .behindWindow
            background.state = .active

            let hosting = NSHostingView(rootView: SettingsView(manager: manager, updater: updater))
            hosting.translatesAutoresizingMaskIntoConstraints = false
            background.addSubview(hosting)
            NSLayoutConstraint.activate([
                hosting.leadingAnchor.constraint(equalTo: background.leadingAnchor),
                hosting.trailingAnchor.constraint(equalTo: background.trailingAnchor),
                hosting.topAnchor.constraint(equalTo: background.topAnchor),
                hosting.bottomAnchor.constraint(equalTo: background.bottomAnchor),
            ])
            window.contentView = background
            window.setContentSize(hosting.fittingSize)
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
        // Don't drop the cursor into the first name field on open.
        settingsWindow?.makeFirstResponder(nil)
    }
}

@main
struct MacOSAudioRenamerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar only — the status item and Settings window are managed by AppDelegate.
        Settings { EmptyView() }
    }
}
