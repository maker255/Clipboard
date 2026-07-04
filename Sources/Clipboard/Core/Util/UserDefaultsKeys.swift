import AppKit
import Carbon.HIToolbox
import Combine
import Foundation

public enum DefaultsKey {
    public static let openPanelHotkeyKey  = "hotkey.openPanel.keyCode"
    public static let openPanelHotkeyMods = "hotkey.openPanel.mods"
    public static let hotkeyMigration     = "hotkey.migration.v1"     // reset legacy ⌥⌘V → ⌥V
    public static let appearance          = "appearance"                 // "system"|"light"|"dark"
    public static let showInMenuBar       = "showInMenuBar"
    public static let maxItems            = "history.maxItems"
    public static let retentionDays       = "history.retentionDays"
    public static let excludedBundleIds   = "history.excludedBundleIds"  // [String] JSON
    public static let honorConcealedTypes = "history.honorConcealedTypes"
    public static let imageQuotaMB        = "history.imageQuotaMB"
    public static let launchAtLoginPref   = "launchAtLoginPref"          // mirrors SMAppService for UI snappiness
}

public struct HotkeyBinding: Equatable, Codable {
    public var keyCode: UInt32
    public var carbonModifiers: UInt32

    public init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    /// Default: ⌥V (Option+V).
    /// Note: this shadows the ◊ character on some layouts; users can rebind
    /// via Settings › Hotkeys.
    public static let defaultOpenPanel = HotkeyBinding(
        keyCode: UInt32(kVK_ANSI_V),
        carbonModifiers: UInt32(optionKey)
    )
}

public enum AppearancePreference: String, CaseIterable, Identifiable {
    case system, light, dark
    public var id: String { rawValue }

    public var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light:  return NSAppearance(named: .aqua)
        case .dark:   return NSAppearance(named: .darkAqua)
        }
    }
}

@MainActor
public final class SettingsStore: ObservableObject {
    public static let shared = SettingsStore()

    private let defaults = UserDefaults.standard

    @Published public var openPanelHotkey: HotkeyBinding
    @Published public var appearance: AppearancePreference {
        didSet { apply(appearance: appearance); defaults.set(appearance.rawValue, forKey: DefaultsKey.appearance) }
    }
    @Published public var showInMenuBar: Bool {
        didSet { defaults.set(showInMenuBar, forKey: DefaultsKey.showInMenuBar) }
    }
    @Published public var maxItems: Int {
        didSet { defaults.set(maxItems, forKey: DefaultsKey.maxItems) }
    }
    @Published public var retentionDays: Int {
        didSet { defaults.set(retentionDays, forKey: DefaultsKey.retentionDays) }
    }
    @Published public var excludedBundleIds: Set<String> {
        didSet {
            let arr = Array(excludedBundleIds)
            if let data = try? JSONEncoder().encode(arr) {
                defaults.set(data, forKey: DefaultsKey.excludedBundleIds)
            }
        }
    }
    @Published public var honorConcealedTypes: Bool {
        didSet { defaults.set(honorConcealedTypes, forKey: DefaultsKey.honorConcealedTypes) }
    }
    @Published public var imageQuotaMB: Int {
        didSet { defaults.set(imageQuotaMB, forKey: DefaultsKey.imageQuotaMB) }
    }

    private init() {
        // Register defaults so first read returns sensible values.
        defaults.register(defaults: [
            DefaultsKey.appearance: AppearancePreference.system.rawValue,
            DefaultsKey.showInMenuBar: true,
            DefaultsKey.maxItems: 1000,
            DefaultsKey.retentionDays: 30,
            DefaultsKey.honorConcealedTypes: true,
            DefaultsKey.imageQuotaMB: 500,
        ])

        // One-time migration: earlier builds saved ⌥⌘V as default. Reset users
        // to the new ⌥V default so the app actually opens on Option+V.
        let migrated = defaults.bool(forKey: DefaultsKey.hotkeyMigration)
        let kc = UInt32(defaults.integer(forKey: DefaultsKey.openPanelHotkeyKey))
        let md = UInt32(defaults.integer(forKey: DefaultsKey.openPanelHotkeyMods))
        if !migrated {
            self.openPanelHotkey = .defaultOpenPanel
            defaults.set(Int(HotkeyBinding.defaultOpenPanel.keyCode),
                         forKey: DefaultsKey.openPanelHotkeyKey)
            defaults.set(Int(HotkeyBinding.defaultOpenPanel.carbonModifiers),
                         forKey: DefaultsKey.openPanelHotkeyMods)
            defaults.set(true, forKey: DefaultsKey.hotkeyMigration)
        } else if kc != 0 {
            self.openPanelHotkey = HotkeyBinding(keyCode: kc, carbonModifiers: md)
        } else {
            self.openPanelHotkey = .defaultOpenPanel
        }

        self.appearance = AppearancePreference(
            rawValue: defaults.string(forKey: DefaultsKey.appearance) ?? "system"
        ) ?? .system
        self.showInMenuBar = defaults.bool(forKey: DefaultsKey.showInMenuBar)
        self.maxItems = defaults.integer(forKey: DefaultsKey.maxItems)
        self.retentionDays = defaults.integer(forKey: DefaultsKey.retentionDays)
        self.honorConcealedTypes = defaults.bool(forKey: DefaultsKey.honorConcealedTypes)
        self.imageQuotaMB = defaults.integer(forKey: DefaultsKey.imageQuotaMB)

        if let data = defaults.data(forKey: DefaultsKey.excludedBundleIds),
           let arr = try? JSONDecoder().decode([String].self, from: data) {
            self.excludedBundleIds = Set(arr)
        } else {
            self.excludedBundleIds = []
        }

        apply(appearance: self.appearance)
    }

    public func updateOpenPanelHotkey(_ binding: HotkeyBinding) {
        openPanelHotkey = binding
        defaults.set(Int(binding.keyCode), forKey: DefaultsKey.openPanelHotkeyKey)
        defaults.set(Int(binding.carbonModifiers), forKey: DefaultsKey.openPanelHotkeyMods)
    }

    private func apply(appearance: AppearancePreference) {
        NSApp?.appearance = appearance.nsAppearance
    }
}
