import Foundation

/// Periodic maintenance: retention deletion, cap eviction, image-quota trimming.
///
/// Runs every 5 minutes on a background queue. Also runs once at start.
public final class CleanupScheduler {
    public let repository: ClipItemRepository
    public let fileStore: FileStore

    private let queue = DispatchQueue(label: "com.local.clipboard.cleanup", qos: .background)
    private var timer: DispatchSourceTimer?
    private let interval: TimeInterval

    public init(repository: ClipItemRepository, fileStore: FileStore, interval: TimeInterval = 300) {
        self.repository = repository
        self.fileStore = fileStore
        self.interval = interval
    }

    public func start() {
        stop()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + interval, repeating: interval)
        t.setEventHandler { [weak self] in self?.runOnce() }
        timer = t
        t.resume()

        // Fire an initial pass shortly after launch.
        queue.asyncAfter(deadline: .now() + 5) { [weak self] in self?.runOnce() }
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }

    public func runOnce() {
        // SettingsStore is @MainActor; snapshot its scalars on main first.
        let (retentionDays, maxItems, imageQuotaMB): (Int, Int, Int) = DispatchQueue.main.sync {
            (SettingsStore.shared.retentionDays,
             SettingsStore.shared.maxItems,
             SettingsStore.shared.imageQuotaMB)
        }
        let imageQuotaBytes = Int64(imageQuotaMB) * 1024 * 1024

        do {
            let deletedHashes = try repository.performRetention(retentionDays: retentionDays, maxItems: maxItems)
            for hash in deletedHashes {
                fileStore.removeArtifacts(hash: hash)
            }
            Log.cleanup.debug("Retention pass deleted \(deletedHashes.count) items")
        } catch {
            Log.cleanup.error("Retention failed: \(String(describing: error))")
        }

        // Image quota: if oversubscribed, drop the oldest images from disk.
        let bytes = fileStore.imagesTotalBytes()
        if bytes > imageQuotaBytes {
            trimImages(target: imageQuotaBytes)
        }
    }

    private func trimImages(target: Int64) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: fileStore.imagesDir,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
        ) else { return }

        let sorted = entries.sorted { a, b in
            let am = (try? a.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let bm = (try? b.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return am < bm
        }

        var total = fileStore.imagesTotalBytes()
        for url in sorted where total > target {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            try? fm.removeItem(at: url)
            // Best-effort: also remove matching thumb.
            let name = url.deletingPathExtension().lastPathComponent
            try? fm.removeItem(at: fileStore.thumbURL(for: name))
            total -= Int64(size)
        }
        Log.cleanup.info("Trimmed images to \(total) bytes (target \(target))")
    }
}
