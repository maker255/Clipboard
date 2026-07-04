import AppKit
import Carbon.HIToolbox

public enum KeyCodes {
    /// Convert Cocoa `NSEvent.ModifierFlags` to Carbon modifier bitfield.
    public static func carbonModifiers(from cocoa: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if cocoa.contains(.command) { mods |= UInt32(cmdKey) }
        if cocoa.contains(.option)  { mods |= UInt32(optionKey) }
        if cocoa.contains(.control) { mods |= UInt32(controlKey) }
        if cocoa.contains(.shift)   { mods |= UInt32(shiftKey) }
        return mods
    }

    public static func cocoaModifiers(from carbon: UInt32) -> NSEvent.ModifierFlags {
        var m: NSEvent.ModifierFlags = []
        if carbon & UInt32(cmdKey)     != 0 { m.insert(.command) }
        if carbon & UInt32(optionKey)  != 0 { m.insert(.option) }
        if carbon & UInt32(controlKey) != 0 { m.insert(.control) }
        if carbon & UInt32(shiftKey)   != 0 { m.insert(.shift) }
        return m
    }

    /// Human-readable modifier glyphs, in the canonical Apple order.
    public static func modifierString(carbon: UInt32) -> String {
        var s = ""
        if carbon & UInt32(controlKey) != 0 { s += "⌃" }
        if carbon & UInt32(optionKey)  != 0 { s += "⌥" }
        if carbon & UInt32(shiftKey)   != 0 { s += "⇧" }
        if carbon & UInt32(cmdKey)     != 0 { s += "⌘" }
        return s
    }

    /// Best-effort human name for a key code. Uses `UCKeyTranslate` for
    /// printable keys and a hand-rolled fallback for special keys.
    public static func keyName(for keyCode: UInt32) -> String {
        if let special = specialKeyNames[Int(keyCode)] { return special }

        // TISCopyCurrentKeyboardLayoutInputSource → UCKeyTranslate
        let source = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()
        guard let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return "Key \(keyCode)"
        }
        let dataRef = unsafeBitCast(layoutData, to: CFData.self)
        let keyLayoutPtr = CFDataGetBytePtr(dataRef)
        let keyLayout = UnsafePointer<UCKeyboardLayout>(OpaquePointer(keyLayoutPtr))

        var deadKeys: UInt32 = 0
        let maxChars = 4
        var actualLength = 0
        var chars = [UniChar](repeating: 0, count: maxChars)
        let err = UCKeyTranslate(
            keyLayout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeys,
            maxChars,
            &actualLength,
            &chars
        )
        guard err == noErr, actualLength > 0 else { return "Key \(keyCode)" }
        return String(utf16CodeUnits: chars, count: actualLength).uppercased()
    }

    /// Compose "⌥⌘V"-style display string.
    public static func displayName(keyCode: UInt32, carbon: UInt32) -> String {
        modifierString(carbon: carbon) + keyName(for: keyCode)
    }

    private static let specialKeyNames: [Int: String] = [
        kVK_Space:              "Space",
        kVK_Return:             "↩",
        kVK_Tab:                "⇥",
        kVK_Delete:             "⌫",
        kVK_ForwardDelete:      "⌦",
        kVK_Escape:             "⎋",
        kVK_LeftArrow:          "←",
        kVK_RightArrow:         "→",
        kVK_UpArrow:            "↑",
        kVK_DownArrow:          "↓",
        kVK_Home:               "↖",
        kVK_End:                "↘",
        kVK_PageUp:             "⇞",
        kVK_PageDown:           "⇟",
        kVK_F1:                 "F1",  kVK_F2:  "F2",  kVK_F3:  "F3",  kVK_F4:  "F4",
        kVK_F5:                 "F5",  kVK_F6:  "F6",  kVK_F7:  "F7",  kVK_F8:  "F8",
        kVK_F9:                 "F9",  kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]
}
