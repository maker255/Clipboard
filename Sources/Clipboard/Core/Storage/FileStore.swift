import AppKit
import Foundation

/// Owns disk layout under Application Support.
///
///     ~/Library/Application Support/com.local.clipboard/
///     ├── clipboard.sqlite
///     ├── images/<sha256>.png
///     ├── thumbs/<sha256>.jpg
///     └── attributed/<sha256>.dat        (archived NSAttributedString for RTF)
public final class FileStore {
    public static let shared = FileStore()

    public let rootURL: URL
    public let databaseURL: URL
    public let imagesDir: URL
    public let thumbsDir: URL
    public let attributedDir: URL

    public init(root: URL? = nil) {
        let base = root ?? AppInfo.applicationSupportDirectory
        self.rootURL = base
        self.databaseURL = base.appendingPathComponent("clipboard.sqlite")
        self.imagesDir = base.appendingPathComponent("images", isDirectory: true)
        self.thumbsDir = base.appendingPathComponent("thumbs", isDirectory: true)
        self.attributedDir = base.appendingPathComponent("attributed", isDirectory: true)

        let fm = FileManager.default
        for dir in [imagesDir, thumbsDir, attributedDir] {
            if !fm.fileExists(atPath: dir.path) {
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }

    public func imageURL(for hash: String) -> URL { imagesDir.appendingPathComponent("\(hash).png") }
    public func thumbURL(for hash: String) -> URL { thumbsDir.appendingPathComponent("\(hash).jpg") }
    public func attributedURL(for hash: String) -> URL { attributedDir.appendingPathComponent("\(hash).dat") }

    @discardableResult
    public func writeImage(_ image: NSImage, hash: String) -> (image: URL, thumb: URL?)? {
        guard let png = pngData(from: image) else { return nil }
        let imgURL = imageURL(for: hash)
        do {
            try png.write(to: imgURL, options: .atomic)
        } catch {
            Log.database.error("writeImage failed: \(String(describing: error))")
            return nil
        }
        let thumbURL = self.thumbURL(for: hash)
        if let thumbData = jpegData(from: image, maxDimension: 256, quality: 0.75) {
            try? thumbData.write(to: thumbURL, options: .atomic)
        }
        return (imgURL, thumbURL)
    }

    public func writeAttributedString(_ attributed: NSAttributedString, hash: String) -> URL? {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: attributed, requiringSecureCoding: true)
            let url = attributedURL(for: hash)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            Log.database.error("writeAttributedString failed: \(String(describing: error))")
            return nil
        }
    }

    public func readAttributedString(hash: String) -> NSAttributedString? {
        let url = attributedURL(for: hash)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: data)
    }

    public func removeArtifacts(hash: String) {
        let fm = FileManager.default
        for url in [imageURL(for: hash), thumbURL(for: hash), attributedURL(for: hash)] {
            try? fm.removeItem(at: url)
        }
    }

    public func imagesTotalBytes() -> Int64 {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: imagesDir, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for url in entries {
            if let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    // MARK: - Private

    private func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    private func jpegData(from image: NSImage, maxDimension: CGFloat, quality: CGFloat) -> Data? {
        let size = image.size
        let scale = min(1.0, maxDimension / max(size.width, size.height))
        let target = NSSize(width: size.width * scale, height: size.height * scale)
        let thumb = NSImage(size: target)
        thumb.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: target),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy, fraction: 1.0)
        thumb.unlockFocus()
        guard let tiff = thumb.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }
}
