import AppKit
import Carbon.HIToolbox

/// Simulates ⌘V into whichever app is frontmost after we restore focus.
public final class PasteEngine {
    public init() {}

    /// Restore the previous app (if given), then post a synthetic ⌘V after a
    /// small delay. If Accessibility trust is not granted, we skip the CGEvent
    /// step — the user can still ⌘V manually since the content is on the
    /// pasteboard.
    public func performPaste(previous: NSRunningApplication?) {
        previous?.activate(options: [])

        guard AccessibilityPermission.isTrusted else {
            Log.paste.notice("Accessibility not granted; skipping synthetic ⌘V")
            return
        }

        // Small delay so the previous app has a chance to become frontmost
        // and its window is ready to receive input.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            Self.postCommandV()
        }
    }

    private static func postCommandV() {
        guard let src = CGEventSource(stateID: .combinedSessionState) else {
            Log.paste.error("CGEventSource creation failed")
            return
        }
        let vKey = CGKeyCode(kVK_ANSI_V)
        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
