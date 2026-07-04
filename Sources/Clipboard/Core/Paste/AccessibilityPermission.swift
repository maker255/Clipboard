import AppKit
import ApplicationServices

public enum AccessibilityPermission {
    /// Non-prompting check.
    public static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Trigger the system's Accessibility prompt (once per (bundle-path, signing-identity)).
    @discardableResult
    public static func requestTrust() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// Open System Settings > Privacy & Security > Accessibility.
    public static func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
