import AppKit
import Combine
import Foundation

/// Simple DI container. Owns long-lived singletons and coordinates lifecycle.
///
/// Kept intentionally small — this is the top of the dependency graph.
/// Features/ViewModels reach for the concrete services they need via
/// `@EnvironmentObject var env: AppEnvironment`.
@MainActor
public final class AppEnvironment: ObservableObject {
    // Core services (lazy — allocation order matters, see start()).
    public let database: Database
    public let fileStore: FileStore
    public let repository: ClipItemRepository

    public let pasteboardMonitor: PasteboardMonitor
    public let pasteEngine: PasteEngine

    public let hotkeyManager: HotkeyManager
    public let panelController: PanelController
    public let statusItemController: StatusItemController

    public let cleanupScheduler: CleanupScheduler
    public let loginItemManager: LoginItemManager

    public let settings: SettingsStore

    private var openPanelHotkeyID: UInt32?

    public init() {
        let fileStore = FileStore.shared
        self.fileStore = fileStore

        do {
            self.database = try Database.makeDefault(fileStore: fileStore)
        } catch {
            Log.database.error("Database init failed: \(String(describing: error))")
            fatalError("Clipboard cannot initialize its database at \(fileStore.databaseURL.path).")
        }
        self.repository = ClipItemRepository(database: database, fileStore: fileStore)

        self.pasteEngine = PasteEngine()
        self.pasteboardMonitor = PasteboardMonitor(repository: repository, fileStore: fileStore)

        self.hotkeyManager = HotkeyManager.shared
        self.settings = SettingsStore.shared

        self.panelController = PanelController(repository: repository, pasteEngine: pasteEngine)
        self.statusItemController = StatusItemController(repository: repository, pasteEngine: pasteEngine)

        self.cleanupScheduler = CleanupScheduler(repository: repository, fileStore: fileStore)
        self.loginItemManager = LoginItemManager()

        panelController.environment = self
        statusItemController.environment = self
    }

    /// Start monitors, register hotkey, install status item.
    public func start() {
        Log.app.info("Environment starting…")

        pasteboardMonitor.start()

        let binding = settings.openPanelHotkey
        openPanelHotkeyID = hotkeyManager.register(
            keyCode: binding.keyCode,
            carbonMods: binding.carbonModifiers
        ) { [weak self] in
            self?.panelController.toggle()
        }

        statusItemController.install()

        cleanupScheduler.start()

        Log.app.info("Environment started.")
    }

    public func stop() {
        pasteboardMonitor.stop()
        if let id = openPanelHotkeyID { hotkeyManager.unregister(id) }
        cleanupScheduler.stop()
        statusItemController.uninstall()
    }

    /// Re-register the global panel hotkey (called from Settings after user re-binds).
    public func reregisterOpenPanelHotkey() {
        if let id = openPanelHotkeyID { hotkeyManager.unregister(id) }
        let binding = settings.openPanelHotkey
        openPanelHotkeyID = hotkeyManager.register(
            keyCode: binding.keyCode,
            carbonMods: binding.carbonModifiers
        ) { [weak self] in
            self?.panelController.toggle()
        }
    }
}
