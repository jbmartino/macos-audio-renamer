import SwiftUI
import AppKit

struct SettingsView: View {
    var manager: AudioDeviceManager
    var updater: Updater

    @State private var expanded: Set<String> = []
    @State private var playingUID: String?
    @State private var listeningUID: String?
    @State private var inputLevel: Float = 0
    @State private var switchInputWithOutput = Preferences.switchInputWithOutput
    @State private var openAtLogin = LoginItem.isEnabled || LoginItem.needsApproval
    @State private var loginNeedsApproval = LoginItem.needsApproval
    @State private var outputTester = OutputTester()
    @State private var inputMonitor = InputLevelMonitor()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section("Devices", footer: "One name covers a device's speaker and microphone. Expand a device to name them separately.") {
                    VStack(spacing: 8) {
                        ForEach(groups) { group in
                            deviceRow(group)
                        }
                    }
                }

                section("Behavior") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $openAtLogin) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Open at login")
                                if loginNeedsApproval {
                                    HStack(spacing: 4) {
                                        Text("Allow it in Login Items to finish.")
                                        Button("Open Settings…") { LoginItem.openSystemSettings() }
                                            .buttonStyle(.link)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                } else if !LoginItem.isInstalledCopy {
                                    Text("Move the app to Applications first.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .toggleStyle(.switch)
                        .disabled(!LoginItem.isInstalledCopy && !openAtLogin)
                        .onChange(of: openAtLogin) { _, value in
                            guard value != (LoginItem.isEnabled || LoginItem.needsApproval) else { return }
                            LoginItem.setEnabled(value)
                            refreshLoginItem()
                        }

                        Divider()

                        Toggle(isOn: $switchInputWithOutput) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Switch microphone with speaker")
                                Text("Picking a speaker from the menu also picks the same device's mic.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        .onChange(of: switchInputWithOutput) { _, value in
                            Preferences.switchInputWithOutput = value
                        }

                        Divider()

                        HStack {
                            Text("Custom names")
                            Spacer()
                            Button("Reset All") { manager.resetAllNames() }
                        }
                    }
                    .padding(14)
                    .glassCard()
                }

                section("Updates") {
                    VStack(alignment: .leading, spacing: 10) {
                        if updater.isEnabled {
                            Toggle(isOn: Binding(
                                get: { updater.automaticUpdates },
                                set: { updater.automaticUpdates = $0 }
                            )) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Update automatically")
                                    Text("Downloads new versions in the background. Restart from the menu to finish.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .toggleStyle(.switch)

                            Divider()
                        }

                        HStack {
                            Text("Version \(updater.currentVersion)")
                                .foregroundStyle(.secondary)
                            Spacer()
                            if updater.isEnabled {
                                Button("Check Now") { updater.checkForUpdates() }
                            } else {
                                Text("Local build — updates off")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(14)
                    .glassCard()
                }
            }
            .padding(20)
            .padding(.top, 18) // room for the transparent title bar
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: 460)
        .frame(maxHeight: 640)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            refreshLoginItem()
            outputTester.onFinish = { playingUID = nil }
            inputMonitor.onLevel = { inputLevel = $0 }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            refreshLoginItem()
        }
        .onDisappear {
            outputTester.stop()
            stopListening()
        }
    }

    /// The switch can also change in System Settings, so re-read it.
    private func refreshLoginItem() {
        openAtLogin = LoginItem.isEnabled || LoginItem.needsApproval
        loginNeedsApproval = LoginItem.needsApproval
    }

    /// Stable order (by hardware, not by custom name) so rows don't jump while typing.
    private var groups: [DeviceGroup] {
        manager.deviceGroups.sorted {
            if $0.physicalName != $1.physicalName {
                return $0.physicalName.localizedCaseInsensitiveCompare($1.physicalName) == .orderedAscending
            }
            return $0.id < $1.id
        }
    }

    // MARK: - Device row

    @ViewBuilder
    private func deviceRow(_ group: DeviceGroup) -> some View {
        let isExpanded = expanded.contains(group.id)
        let isPaired = group.output != nil && group.input != nil

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon(for: group))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    NameField(
                        placeholder: group.physicalName,
                        text: Binding(
                            get: { manager.name(for: group) },
                            set: { manager.rename(group: group, to: $0) }
                        )
                    )
                    Text(subtitle(for: group))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                if let output = group.output {
                    testButton(
                        active: playingUID == output.uid,
                        icon: "play.fill",
                        help: "Play test sound"
                    ) { toggleChime(output) }
                }
                if let input = group.input {
                    testButton(
                        active: listeningUID == input.uid,
                        icon: "mic.fill",
                        help: "Test microphone"
                    ) { toggleListening(input) }
                }

                if isPaired {
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            if isExpanded { expanded.remove(group.id) } else { expanded.insert(group.id) }
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Name speaker and mic separately")
                }
            }

            if let input = group.input, listeningUID == input.uid {
                LevelMeter(level: inputLevel)
                    .padding(.leading, 32)
                    .transition(.opacity)
            }

            if isExpanded, let output = group.output, let input = group.input {
                VStack(spacing: 6) {
                    overrideField("Speaker", device: output, fallback: sharedName(group))
                    overrideField("Mic", device: input, fallback: sharedName(group))
                }
                .padding(.leading, 32)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .glassCard()
    }

    private func overrideField(_ label: String, device: AudioDevice, fallback: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)
            NameField(
                placeholder: fallback,
                text: Binding(
                    get: { manager.overrideName(for: device) },
                    set: { manager.setOverrideName($0, for: device) }
                ),
                size: 12
            )
        }
    }

    private func testButton(active: Bool, icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: active ? "stop.fill" : icon)
                .font(.system(size: 10))
                .frame(width: 26, height: 26)
                .background(Circle().fill(active ? Color.red.opacity(0.2) : Color.primary.opacity(0.08)))
                .foregroundStyle(active ? Color.red : Color.primary.opacity(0.8))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(active ? "Stop" : help)
    }

    private func section<Content: View>(_ title: String, footer: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .padding(.leading, 4)
            content()
            if let footer {
                Text(footer)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Helpers

    private func sharedName(_ group: DeviceGroup) -> String {
        let name = manager.name(for: group)
        return name.isEmpty ? group.physicalName : name
    }

    private func icon(for group: DeviceGroup) -> String {
        switch (group.output != nil, group.input != nil) {
        case (true, true): return "hifispeaker.fill"
        case (true, false): return "speaker.wave.2.fill"
        default: return "mic.fill"
        }
    }

    private func subtitle(for group: DeviceGroup) -> String {
        var parts: [String] = []
        let members = [group.output?.name, group.input?.name].compactMap { $0 }
        parts.append(Array(NSOrderedSet(array: members)).compactMap { $0 as? String }.joined(separator: " + "))
        if !group.id.hasPrefix("name:"), group.serial != group.id {
            parts.append(DeviceNaming.shortSerial(group.serial))
        }
        return parts.joined(separator: " · ")
    }

    private func toggleChime(_ device: AudioDevice) {
        outputTester.toggle(uid: device.uid, deviceID: device.id)
        playingUID = outputTester.playingUID
    }

    private func toggleListening(_ device: AudioDevice) {
        if listeningUID == device.uid {
            stopListening()
            return
        }
        stopListening()
        listeningUID = device.uid
        inputMonitor.start(deviceUID: device.uid)
    }

    private func stopListening() {
        inputMonitor.stop()
        listeningUID = nil
        inputLevel = 0
    }
}

// MARK: - Components

/// Borderless text field that reads as a label until you click into it.
private struct NameField: View {
    let placeholder: String
    @Binding var text: String
    var size: CGFloat = 13
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: size, weight: size >= 13 ? .medium : .regular))
            .focused($focused)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(focused ? 0.10 : 0.04))
            )
            .onSubmit { focused = false }
    }
}

private struct LevelMeter: View {
    let level: Float

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.1))
                Capsule().fill(Color.green)
                    .frame(width: max(4, geo.size.width * CGFloat(level)))
            }
        }
        .frame(height: 5)
        .animation(.linear(duration: 0.05), value: level)
    }
}

extension View {
    /// Liquid Glass on macOS 26+, a translucent card on earlier systems.
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 14) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.legacyCard(cornerRadius: cornerRadius)
        }
        #else
        self.legacyCard(cornerRadius: cornerRadius)
        #endif
    }

    private func legacyCard(cornerRadius: CGFloat) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                )
        )
    }
}
