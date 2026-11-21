import AppKit
import SwiftUI

/// The menu bar menu. A native NSMenu: it gets the system glass material,
/// closes when you click anywhere else, and shows keyboard shortcuts.
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let manager: AudioDeviceManager
    private let updater: Updater
    private let menu = NSMenu()
    private let openSettings: () -> Void
    private let renamePanel = RenamePanelController()
    private let highlight = MenuHighlight()

    init(manager: AudioDeviceManager, updater: Updater, openSettings: @escaping () -> Void) {
        self.manager = manager
        self.updater = updater
        self.openSettings = openSettings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        statusItem.button?.image = NSImage(
            systemSymbolName: "speaker.wave.2.fill",
            accessibilityDescription: "macOS Audio Renamer"
        )
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
    }

    // Rebuild every time the menu opens so it always reflects current devices.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(choiceItem(.output))
        menu.addItem(choiceItem(.input))
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        // Hidden while an update is already listed below, and on local builds (no feed).
        if updater.isEnabled && updater.pendingUpdate == nil {
            let check = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
            check.target = self
            menu.addItem(check)
        }

        menu.addItem(.separator())

        if let update = updater.pendingUpdate {
            menu.addItem(disabled(update.readyToInstall
                ? "Version \(update.version) is ready"
                : "Version \(update.version) is available"))
            let install = NSMenuItem(
                title: update.readyToInstall ? "Restart to Update" : "Update…",
                action: #selector(installUpdate),
                keyEquivalent: ""
            )
            install.target = self
            menu.addItem(install)
            menu.addItem(.separator())
        }

        let quit = NSMenuItem(title: "Quit Audio Renamer", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    // MARK: - Items

    private enum Role {
        case output, input
        var title: String { self == .output ? "Output" : "Input" }
        var symbol: String { self == .output ? "speaker.wave.2.fill" : "mic.fill" }
    }

    /// "Output ▸" / "Input ▸": shows the device in use, a pencil to rename it,
    /// and a submenu to pick a different one.
    private func choiceItem(_ role: Role) -> NSMenuItem {
        let currentUID = role == .output ? manager.defaultOutputUID : manager.defaultInputUID
        let current = manager.devices.first { $0.uid == currentUID }
        let options = manager.devices.filter { role == .output ? $0.hasOutput : $0.hasInput }

        let item = NSMenuItem(title: role.title, action: nil, keyEquivalent: "")
        item.submenu = deviceSubmenu(role, options: options, currentUID: currentUID)

        let row = ChoiceMenuRow(
            title: role.title,
            symbol: role.symbol,
            deviceName: current.map { menuLabel(for: $0, among: options) } ?? "None",
            highlight: highlight,
            itemID: ObjectIdentifier(item),
            onRename: current.map { device in
                { [weak self] in
                    self?.menu.cancelTracking()
                    DispatchQueue.main.async { self?.rename(device) }
                }
            }
        )
        let view = NSHostingView(rootView: row)
        view.frame = NSRect(origin: .zero, size: view.fittingSize)
        view.autoresizingMask = [.width]
        item.view = view
        return item
    }

    private func deviceSubmenu(_ role: Role, options: [AudioDevice], currentUID: String?) -> NSMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        if options.isEmpty {
            submenu.addItem(disabled(role == .output ? "No output devices" : "No input devices"))
        }
        let preferred = role == .output ? Preferences.preferredOutputUID : Preferences.preferredInputUID
        for device in sorted(options, preferred: preferred) {
            submenu.addItem(deviceItem(
                device,
                label: menuLabel(for: device, among: options),
                isSelected: device.uid == currentUID
            ) { [weak self] in
                if role == .output {
                    self?.manager.selectOutput(uid: device.uid)
                } else {
                    self?.manager.setDefaultInput(uid: device.uid)
                }
            })
        }
        return submenu
    }

    // Keeps "Output ▸" / "Input ▸" highlighted while their submenu is open, like native items.
    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        guard menu === self.menu else { return }
        highlight.itemID = item.map(ObjectIdentifier.init)
    }

    func menuDidClose(_ menu: NSMenu) {
        if menu === self.menu { highlight.itemID = nil }
    }

    /// A device row: checkmark, name, and a pencil (on hover) that opens the rename popup.
    private func deviceItem(
        _ device: AudioDevice, label: String, isSelected: Bool, onSelect: @escaping () -> Void
    ) -> NSMenuItem {
        let item = NSMenuItem()
        let row = DeviceMenuRow(
            label: label,
            isSelected: isSelected,
            onSelect: { [weak self, weak item] in
                item?.menu?.cancelTracking()
                self?.menu.cancelTracking()
                onSelect()
            },
            onRename: { [weak self, weak item] in
                item?.menu?.cancelTracking()
                self?.menu.cancelTracking()
                // Let the menu finish closing before the popup takes focus.
                DispatchQueue.main.async { self?.rename(device) }
            }
        )
        let view = NSHostingView(rootView: row)
        view.frame = NSRect(origin: .zero, size: view.fittingSize)
        view.autoresizingMask = [.width]
        item.view = view
        return item
    }

    private func rename(_ device: AudioDevice) {
        guard let group = manager.deviceGroups.first(where: { $0.id == device.hardwareGroupKey }) else { return }
        let isPaired = group.output != nil && group.input != nil
        // If this speaker/mic already has its own name, edit that; otherwise the device's one name.
        let override = manager.overrideName(for: device)
        let editsOverride = !override.isEmpty

        let originals = [group.output?.name, group.input?.name].compactMap { $0 }
        let detail = editsOverride
            ? "Only this \(device.hasOutput ? "speaker" : "mic") · \(device.name)"
            : (isPaired ? "Used for speaker and mic · " : "") + Array(NSOrderedSet(array: originals)).compactMap { $0 as? String }.joined(separator: " + ")

        renamePanel.show(
            title: "Rename",
            currentName: editsOverride ? override : manager.name(for: group),
            placeholder: group.physicalName,
            detail: detail,
            below: statusItem.button,
            onSave: { [weak self] name in
                guard let self else { return }
                if editsOverride {
                    self.manager.setOverrideName(name, for: device)
                } else {
                    self.manager.rename(group: group, to: name)
                }
            },
            onMoreOptions: { [weak self] in self?.openSettings() }
        )
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    /// Identical devices that haven't been renamed (e.g. two Studio Displays)
    /// get a short serial so they can be told apart.
    private func menuLabel(for device: AudioDevice, among list: [AudioDevice]) -> String {
        let duplicates = list.filter { $0.displayLabel == device.displayLabel }
        guard duplicates.count > 1 else { return device.displayLabel }
        let parts = device.hardwareGroupKey.split(separator: ":")
        guard parts.count >= 3, !device.hardwareGroupKey.hasPrefix("name:") else { return device.displayLabel }
        return "\(device.displayLabel) (\(DeviceNaming.shortSerial(String(parts[2]))))"
    }

    private func sorted(_ devices: [AudioDevice], preferred: String?) -> [AudioDevice] {
        devices.sorted {
            let p0 = $0.uid == preferred, p1 = $1.uid == preferred
            if p0 != p1 { return p0 }
            return $0.displayLabel.localizedCaseInsensitiveCompare($1.displayLabel) == .orderedAscending
        }
    }

    // MARK: - Actions

    @objc private func showSettings() {
        openSettings()
    }

    @objc private func checkForUpdates() {
        updater.checkForUpdates()
    }

    @objc private func installUpdate() {
        updater.installNow()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

/// Draws like a native menu item (rounded highlight on hover, checkmark), plus a pencil button.
private struct DeviceMenuRow: View {
    let label: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onRename: () -> Void
    @State private var hovering = false
    @State private var pencilHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .semibold))
                .opacity(isSelected ? 1 : 0)
                .frame(width: 12)
            Text(label)
                .font(.system(size: 13))
                .lineLimit(1)
            Spacer(minLength: 16)
            Button(action: onRename) {
                Image(systemName: "pencil")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 22, height: 18)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.white.opacity(pencilHovering ? 0.25 : 0))
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Rename")
            .onHover { pencilHovering = $0 }
            .opacity(hovering ? 1 : 0.35)
        }
        .foregroundStyle(hovering ? Color.white : Color.primary)
        .padding(.leading, 9)
        .padding(.trailing, 6)
        .frame(height: 24)
        .frame(minWidth: 240)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(hovering ? Color.accentColor : Color.clear)
        )
        .padding(.horizontal, 5)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: onSelect)
    }
}

final class MenuHighlight: ObservableObject {
    @Published var itemID: ObjectIdentifier?
}

/// "Output ▸" / "Input ▸" row: icon, role, current device, pencil, chevron.
private struct ChoiceMenuRow: View {
    let title: String
    let symbol: String
    let deviceName: String
    @ObservedObject var highlight: MenuHighlight
    let itemID: ObjectIdentifier
    let onRename: (() -> Void)?
    @State private var pencilHovering = false

    private var isHighlighted: Bool { highlight.itemID == itemID }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 16)
                .opacity(isHighlighted ? 1 : 0.7)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .opacity(isHighlighted ? 0.85 : 0.55)
                Text(deviceName)
                    .font(.system(size: 13))
                    .lineLimit(1)
            }
            Spacer(minLength: 16)
            if let onRename {
                Button(action: onRename) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 22, height: 18)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.white.opacity(pencilHovering ? 0.25 : 0))
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Rename \(deviceName)")
                .onHover { pencilHovering = $0 }
                .opacity(isHighlighted ? 1 : 0.35)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .opacity(isHighlighted ? 1 : 0.5)
        }
        .foregroundStyle(isHighlighted ? Color.white : Color.primary)
        .padding(.leading, 9)
        .padding(.trailing, 8)
        .frame(height: 36)
        .frame(minWidth: 260)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHighlighted ? Color.accentColor : Color.clear)
        )
        .padding(.horizontal, 5)
        .contentShape(Rectangle())
    }
}
