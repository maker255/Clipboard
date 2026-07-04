import AppKit
import SwiftUI

/// Owns the singleton floating panel — creates the window lazily, positions it,
/// wires SwiftUI content, and handles show/hide/paste-restore lifecycle.
@MainActor
public final class PanelController {
    public weak var environment: AppEnvironment?

    public let repository: ClipItemRepository
    public let pasteEngine: PasteEngine
    public let tracker = FrontmostAppTracker()

    private var window: PanelWindow?
    private var resignObserver: NSObjectProtocol?

    public init(repository: ClipItemRepository, pasteEngine: PasteEngine) {
        self.repository = repository
        self.pasteEngine = pasteEngine
    }

    // MARK: - Public API

    public func toggle() {
        if window?.isVisible == true { hide() } else { show() }
    }

    public func show() {
        tracker.snapshot()

        let panel = window ?? makePanel()
        window = panel

        centerOnMouseScreen(panel)

        // Non-activating panel + explicit app activation is the right cocktail:
        // the panel becomes key and receives keyboard input, but we don't do
        // a Dock-icon bounce.
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    public func hide() {
        window?.orderOut(nil)
        tracker.restore()
    }

    /// Called by the SwiftUI list on Return. Writes the item, hides the panel,
    /// restores focus to the previous app, then simulates ⌘V.
    public func pasteAndHide(item: ClipItem, preferPlainText: Bool = false) {
        PasteboardWriter.write(item, preferPlainText: preferPlainText, to: .general)
        window?.orderOut(nil)
        try? repository.bumpUsage(id: item.id ?? -1)
        pasteEngine.performPaste(previous: tracker.lastApp)
    }

    // MARK: - Panel construction

    private func makePanel() -> PanelWindow {
        let style: NSWindow.StyleMask = [.nonactivatingPanel, .borderless, .fullSizeContentView, .titled]
        let panel = PanelWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 500),
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = true
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false

        panel.onEscape = { [weak self] in self?.hide() }
        panel.onKeyDown = { [weak self] event in
            // Cmd+W closes.
            if event.keyCode == 13 /* kVK_ANSI_W */ && event.modifierFlags.contains(.command) {
                self?.hide()
                return true
            }
            return false
        }

        // Dismiss when the panel resigns key (e.g. user clicks outside).
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            // Small delay lets in-panel focus transitions settle without dismissing.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self, let w = self.window, !w.isKeyWindow else { return }
                self.hide()
            }
        }

        // SwiftUI root.
        if let env = environment {
            let root = ClipListView(repository: repository).environmentObject(env)
            panel.contentView = NSHostingView(rootView: root)
        } else {
            panel.contentView = NSHostingView(rootView: Text("Environment not ready").padding())
        }

        return panel
    }

    private func centerOnMouseScreen(_ panel: PanelWindow) {
        let mouseLoc = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main
        guard let screen else { return }
        let size = panel.frame.size
        let origin = NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.midY - size.height / 2 + 60   // slight upward bias, Raycast-style
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}
