import AppKit

/// Owns the `NSStatusItem`. Left click toggles the panel; right click shows an
/// NSMenu with recent items, Settings, and Quit.
@MainActor
public final class StatusItemController: NSObject {
    public weak var environment: AppEnvironment?
    public let repository: ClipItemRepository
    public let pasteEngine: PasteEngine

    private var statusItem: NSStatusItem?
    private let menuBuilder = RecentItemsMenuBuilder()

    public init(repository: ClipItemRepository, pasteEngine: PasteEngine) {
        self.repository = repository
        self.pasteEngine = pasteEngine
        super.init()
    }

    public func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
            button.image = NSImage(systemSymbolName: "doc.on.clipboard",
                                    accessibilityDescription: "Clipboard")?
                                    .withSymbolConfiguration(config)
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    public func uninstall() {
        if let item = statusItem { NSStatusBar.system.removeStatusItem(item) }
        statusItem = nil
    }

    @objc private func handleClick(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            environment?.panelController.toggle()
            return
        }

        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            presentMenu()
        } else {
            environment?.panelController.toggle()
        }
    }

    private func presentMenu() {
        guard let env = environment, let item = statusItem else { return }
        let menu = menuBuilder.buildMenu(environment: env)
        item.menu = menu
        item.button?.performClick(nil)
        // Detach the menu so left-click continues to toggle the panel next time.
        DispatchQueue.main.async { [weak self] in self?.statusItem?.menu = nil }
    }
}
