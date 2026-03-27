import SwiftUI

@main
struct StudioDisplayRenamerApp: App {
    @State private var manager = AudioDeviceManager()

    var body: some Scene {
        MenuBarExtra("Studio Display Renamer", systemImage: "speaker.wave.2.fill") {
            MenuBarView(manager: manager)
        }
        .menuBarExtraStyle(.menu)

        Window("Settings", id: "settings") {
            SettingsView(manager: manager)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
