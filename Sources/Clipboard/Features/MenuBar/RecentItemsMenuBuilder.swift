import AppKit

@MainActor
public final class RecentItemsMenuBuilder {
    public init() {}

    public func buildMenu(environment: AppEnvironment) -> NSMenu {
        let menu = NSMenu()

        let show = NSMenuItem(
            title: "Show Clipboard",
            action: #selector(EnvironmentActions.showPanel(_:)),
            keyEquivalent: "v"
        )
        show.keyEquivalentModifierMask = [.command, .option]
        show.target = EnvironmentActions.shared
        show.representedObject = environment
        menu.addItem(show)

        menu.addItem(.separator())

        // Recent items submenu (top 5)
        let recent = NSMenuItem(title: "Recent Items", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "Recent")
        if let items = try? environment.repository.recent(limit: 5), !items.isEmpty {
            for (idx, item) in items.enumerated() {
                let title = shortLabel(for: item, maxLength: 60)
                let m = NSMenuItem(
                    title: "\(idx + 1). \(title)",
                    action: #selector(EnvironmentActions.pasteItem(_:)),
                    keyEquivalent: ""
                )
                m.target = EnvironmentActions.shared
                m.representedObject = PastePayload(environment: environment, item: item)
                submenu.addItem(m)
            }
        } else {
            let empty = NSMenuItem(title: "No items yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
        }
        recent.submenu = submenu
        menu.addItem(recent)

        menu.addItem(.separator())

        let clear = NSMenuItem(
            title: "Clear History…",
            action: #selector(EnvironmentActions.clearHistory(_:)),
            keyEquivalent: ""
        )
        clear.target = EnvironmentActions.shared
        clear.representedObject = environment
        menu.addItem(clear)

        let settings = NSMenuItem(
            title: "Settings…",
            action: #selector(EnvironmentActions.openSettings(_:)),
            keyEquivalent: ","
        )
        settings.target = EnvironmentActions.shared
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit Clipboard",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)

        return menu
    }

    private func shortLabel(for item: ClipItem, maxLength: Int) -> String {
        let raw: String
        switch item.kind {
        case .image: raw = "🖼 " + (item.textContent ?? "Image")
        case .file:  raw = "📎 " + (item.textContent ?? "File")
        default:     raw = (item.textContent ?? item.kind.rawValue)
                        .replacingOccurrences(of: "\n", with: " ")
        }
        if raw.count > maxLength {
            return String(raw.prefix(maxLength)) + "…"
        }
        return raw
    }
}

// MARK: - Target/action bridge

/// NSMenuItem `action:` needs an ObjC selector; SwiftUI-friendly closures don't
/// map cleanly to `#selector`, so we use a small target that reads its context
/// from the menu item's `representedObject`.
@MainActor
final class EnvironmentActions: NSObject {
    static let shared = EnvironmentActions()

    @objc func showPanel(_ sender: NSMenuItem) {
        guard let env = sender.representedObject as? AppEnvironment else { return }
        env.panelController.show()
    }

    @objc func pasteItem(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? PastePayload else { return }
        payload.environment.panelController.tracker.snapshot()
        payload.environment.panelController.pasteAndHide(item: payload.item, preferPlainText: true)
    }

    @objc func clearHistory(_ sender: NSMenuItem) {
        guard let env = sender.representedObject as? AppEnvironment else { return }
        let alert = NSAlert()
        alert.messageText = "Clear all clipboard history?"
        alert.informativeText = "This cannot be undone. Pinned and favorited items will also be removed."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            try? env.repository.deleteAll()
        }
    }

    @objc func openSettings(_ sender: NSMenuItem) {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}

final class PastePayload {
    let environment: AppEnvironment
    let item: ClipItem
    init(environment: AppEnvironment, item: ClipItem) {
        self.environment = environment
        self.item = item
    }
}
