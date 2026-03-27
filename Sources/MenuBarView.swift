import SwiftUI

struct MenuBarView: View {
    var manager: AudioDeviceManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let outputDevices = manager.devices.filter(\.hasOutput)
        let inputDevices = manager.devices.filter(\.hasInput)

        // Paired groups get a "Use Both" shortcut
        let pairedGroups = manager.deviceGroups.filter { $0.input != nil && $0.output != nil }

        if !pairedGroups.isEmpty {
            Section("Use Both (Input + Output)") {
                ForEach(pairedGroups) { group in
                    let isActiveOutput = group.output?.uid == manager.defaultOutputUID
                    let isActiveInput = group.input?.uid == manager.defaultInputUID
                    let isBothActive = isActiveOutput && isActiveInput

                    Button {
                        manager.setBoth(group: group)
                    } label: {
                        HStack {
                            Text(group.displayLabel)
                            Spacer()
                            if isBothActive {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        }

        Section("Output") {
            ForEach(outputDevices) { device in
                Button {
                    manager.setDefaultOutput(uid: device.uid)
                } label: {
                    HStack {
                        Text(device.displayLabel)
                        Spacer()
                        if device.uid == manager.defaultOutputUID {
                            Image(systemName: "checkmark")
                        }
                        if device.uid == Preferences.preferredOutputUID {
                            Image(systemName: "star.fill")
                        }
                    }
                }
            }
        }

        Section("Input") {
            ForEach(inputDevices) { device in
                Button {
                    manager.setDefaultInput(uid: device.uid)
                } label: {
                    HStack {
                        Text(device.displayLabel)
                        Spacer()
                        if device.uid == manager.defaultInputUID {
                            Image(systemName: "checkmark")
                        }
                        if device.uid == Preferences.preferredInputUID {
                            Image(systemName: "star.fill")
                        }
                    }
                }
            }
        }

        Divider()

        Button("Settings...") {
            openWindow(id: "settings")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
