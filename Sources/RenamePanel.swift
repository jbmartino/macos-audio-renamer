import AppKit
import SwiftUI

/// The small glass "Rename" popup that opens under the menu bar icon from a row's pencil.
/// Return saves, Escape or clicking anywhere else cancels.
final class RenamePanelController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?

    func show(
        title: String,
        currentName: String,
        placeholder: String,
        detail: String,
        below anchor: NSStatusBarButton?,
        onSave: @escaping (String) -> Void,
        onMoreOptions: @escaping () -> Void
    ) {
        close()

        let view = RenameView(
            title: title,
            name: currentName,
            placeholder: placeholder,
            detail: detail,
            onSave: { [weak self] name in
                onSave(name)
                self?.close()
            },
            onCancel: { [weak self] in self?.close() },
            onMoreOptions: { [weak self] in
                self?.close()
                onMoreOptions()
            }
        )
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)

        let panel = KeyablePanel(
            contentRect: hosting.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.setFrameOrigin(origin(for: hosting.frame.size, below: anchor))

        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        // Recompute the shadow from the rounded glass shape once it has drawn.
        DispatchQueue.main.async { panel.invalidateShadow() }
    }

    func close() {
        panel?.delegate = nil
        panel?.orderOut(nil)
        panel = nil
    }

    // Clicking anywhere else closes it, like a menu.
    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    /// Just under the status item, kept on screen.
    private func origin(for size: NSSize, below anchor: NSStatusBarButton?) -> NSPoint {
        guard let button = anchor, let window = button.window else {
            let screen = NSScreen.main?.visibleFrame ?? .zero
            return NSPoint(x: screen.midX - size.width / 2, y: screen.maxY - size.height - 8)
        }
        let buttonFrame = window.convertToScreen(button.convert(button.bounds, to: nil))
        let visible = (window.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        var x = buttonFrame.midX - size.width / 2
        x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
        return NSPoint(x: x, y: buttonFrame.minY - size.height - 6)
    }
}

/// Borderless panels can't take keyboard focus unless they say so.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

private struct RenameView: View {
    let title: String
    @State var name: String
    let placeholder: String
    let detail: String
    let onSave: (String) -> Void
    let onCancel: () -> Void
    let onMoreOptions: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))

            VStack(alignment: .leading, spacing: 4) {
                TextField(placeholder, text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.accentColor.opacity(focused ? 0.6 : 0), lineWidth: 1))
                    .focused($focused)
                    .onSubmit { onSave(name) }
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                Button("More Options…", action: onMoreOptions)
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save") { onSave(name) }
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.small)
        }
        .padding(14)
        .frame(width: 280)
        .glassCard(cornerRadius: 16)
        .onAppear { focused = true }
    }
}
