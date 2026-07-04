import AppKit

/// NSPanel subclass that MUST override `canBecomeKey`. Without this the
/// search field inside the SwiftUI content will silently refuse keystrokes
/// — the single most common pitfall of building Raycast-style panels.
public final class PanelWindow: NSPanel {
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { false }

    /// Route Escape / Cmd+W keydown to the controller for dismissal.
    public var onKeyDown: ((NSEvent) -> Bool)?

    public override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) == true { return }
        super.keyDown(with: event)
    }

    public override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    public var onEscape: (() -> Void)?
}
