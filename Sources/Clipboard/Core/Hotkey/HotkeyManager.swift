import AppKit
import Carbon.HIToolbox

/// A thin Swift wrapper over Carbon's `RegisterEventHotKey`.
///
/// One shared handler routes all hotkey events to per-ID callbacks. Callers get
/// back an opaque UInt32 ID they can use to `unregister` later.
public final class HotkeyManager {
    public static let shared = HotkeyManager()

    private var handlerRef: EventHandlerRef?
    private var registrations: [UInt32: (ref: EventHotKeyRef, action: () -> Void)] = [:]
    private var nextID: UInt32 = 1

    // 'CLIP' as a 4-char OSType.
    private let signature: OSType = {
        var s: OSType = 0
        for ch in "CLIP".utf8 {
            s = (s << 8) | OSType(ch)
        }
        return s
    }()

    private init() {
        installGlobalHandler()
    }

    /// Register a hotkey. `keyCode` uses `kVK_*` values; `carbonMods` uses
    /// `cmdKey | optionKey | ...`. Returns an internal ID or 0 on failure.
    @discardableResult
    public func register(keyCode: UInt32, carbonMods: UInt32, action: @escaping () -> Void) -> UInt32 {
        let id = nextID
        nextID += 1

        var hkID = EventHotKeyID(signature: signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            carbonMods,
            hkID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else {
            Log.hotkey.error("RegisterEventHotKey failed (status=\(status))")
            return 0
        }
        registrations[id] = (ref, action)
        Log.hotkey.info("Registered hotkey id=\(id) keyCode=\(keyCode) mods=0x\(String(carbonMods, radix: 16))")
        _ = hkID   // silence "never read" for older SDKs
        return id
    }

    public func unregister(_ id: UInt32) {
        guard let entry = registrations.removeValue(forKey: id) else { return }
        UnregisterEventHotKey(entry.ref)
        Log.hotkey.info("Unregistered hotkey id=\(id)")
    }

    public func unregisterAll() {
        for (_, entry) in registrations { UnregisterEventHotKey(entry.ref) }
        registrations.removeAll()
    }

    fileprivate func fire(id: UInt32) {
        registrations[id]?.action()
    }

    // MARK: - Private

    private func installGlobalHandler() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyEventHandler,
            1,
            &spec,
            selfPtr,
            &handlerRef
        )
        if status != noErr {
            Log.hotkey.error("InstallEventHandler failed (status=\(status))")
        }
    }
}

/// C-compatible handler trampoline. Must be a top-level function so it can be
/// passed as `EventHandlerUPP`.
private let hotkeyEventHandler: EventHandlerUPP = { _, eventRef, userData in
    guard let eventRef, let userData else { return noErr }
    var hkID = EventHotKeyID()
    let status = GetEventParameter(
        eventRef,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hkID
    )
    guard status == noErr else { return status }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async { manager.fire(id: hkID.id) }
    return noErr
}
