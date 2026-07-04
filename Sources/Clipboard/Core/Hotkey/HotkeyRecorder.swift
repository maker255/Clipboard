import AppKit

/// Captures the next key-down event and reports it as a `HotkeyBinding`.
///
/// Used by the Settings > Hotkeys tab. The recorder is armed until the caller
/// invokes `stop()` or a key is captured.
@MainActor
public final class HotkeyRecorder {
    private var monitor: Any?
    private var onCaptured: ((HotkeyBinding) -> Void)?
    private var onCanceled: (() -> Void)?

    public init() {}

    /// Begin listening. Any local key-down with at least one modifier will be
    /// captured. Esc cancels.
    public func start(onCaptured: @escaping (HotkeyBinding) -> Void,
                      onCanceled: @escaping () -> Void = {}) {
        stop()
        self.onCaptured = onCaptured
        self.onCanceled = onCanceled

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // Escape cancels.
            if event.keyCode == 53 /* kVK_Escape */ {
                self.onCanceled?()
                self.stop()
                return nil
            }
            // Require at least one non-shift modifier so we don't grab plain
            // letters. (⇧ + letter alone would just be a capital letter.)
            let interesting: NSEvent.ModifierFlags = [.command, .option, .control]
            guard !mods.intersection(interesting).isEmpty else { return event }

            let binding = HotkeyBinding(
                keyCode: UInt32(event.keyCode),
                carbonModifiers: KeyCodes.carbonModifiers(from: mods)
            )
            self.onCaptured?(binding)
            self.stop()
            return nil
        }
    }

    public func stop() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
        onCaptured = nil
        onCanceled = nil
    }
}
