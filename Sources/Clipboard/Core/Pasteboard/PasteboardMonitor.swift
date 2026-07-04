import AppKit
import Combine
import Foundation

/// Polls `NSPasteboard.general.changeCount` and dispatches the read to the
/// main queue.
///
/// `NSPasteboard` is documented as main-thread only, so we only touch the
/// `changeCount` integer from the background timer (safe primitive read) and
/// hop to main for the actual `types` / `string(forType:)` calls.
public final class PasteboardMonitor {
    public let repository: ClipItemRepository
    public let reader: PasteboardReader

    private let pasteboard: NSPasteboard
    private let interval: TimeInterval
    private let queue = DispatchQueue(label: "com.local.clipboard.pasteboard", qos: .utility)
    private var timer: DispatchSourceTimer?

    private var lastSeenChangeCount: Int
    private var lastInsertedHash: String?
    private var pendingWorkItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval = 0.15

    public init(repository: ClipItemRepository,
                fileStore: FileStore,
                pasteboard: NSPasteboard = .general,
                interval: TimeInterval = 0.4) {
        self.repository = repository
        self.reader = PasteboardReader(fileStore: fileStore)
        self.pasteboard = pasteboard
        self.interval = interval
        self.lastSeenChangeCount = pasteboard.changeCount
    }

    public func start() {
        stop()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + interval, repeating: interval)
        t.setEventHandler { [weak self] in self?.tick() }
        timer = t
        t.resume()
        Log.pasteboard.info("PasteboardMonitor started (interval=\(self.interval)s)")
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }

    // MARK: - Private

    private func tick() {
        let current = pasteboard.changeCount
        guard current != lastSeenChangeCount else { return }
        lastSeenChangeCount = current

        // Debounce on main so both the coalescing timer and the actual read
        // run on the main queue where NSPasteboard is safe.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pendingWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in self?.processCurrentPasteboard() }
            self.pendingWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + self.debounceInterval, execute: item)
        }
    }

    @MainActor
    private func processCurrentPasteboard() {
        let frontmost = NSWorkspace.shared.frontmostApplication
        let bundleId = frontmost?.bundleIdentifier
        let appName = frontmost?.localizedName

        // Skip our own writes (paste-back triggers a changeCount tick).
        if bundleId == AppInfo.bundleIdentifier { return }

        // Honor user exclude list.
        if let bid = bundleId, SettingsStore.shared.excludedBundleIds.contains(bid) {
            Log.pasteboard.debug("Skipping paste from excluded app: \(bid)")
            return
        }

        // If the user disabled the concealed-type filter, skip that check.
        // Otherwise PasteboardReader honors it internally via ConcealedTypes.

        guard let draft = reader.read(
            from: pasteboard,
            sourceBundleId: bundleId,
            sourceAppName: appName
        ) else { return }

        if draft.contentHash == lastInsertedHash { return }

        do {
            _ = try repository.insertOrBump(draft)
            lastInsertedHash = draft.contentHash
            Log.pasteboard.debug("Captured \(draft.kind.rawValue) from \(appName ?? "unknown")")
        } catch {
            Log.pasteboard.error("insertOrBump failed: \(String(describing: error))")
        }
    }
}
