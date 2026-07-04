import AppKit
import Foundation

/// Reads a single "change" on `NSPasteboard.general` and produces a `ClipItemDraft`.
///
/// Priority (first match wins): fileURL → image → rtf → html → text.
/// Text is further classified into `.markdown` / `.code(lang)` / `.text`.
public final class PasteboardReader {
    public let fileStore: FileStore

    public init(fileStore: FileStore) {
        self.fileStore = fileStore
    }

    public func read(from pasteboard: NSPasteboard = .general,
                     sourceBundleId: String?,
                     sourceAppName: String?) -> ClipItemDraft? {
        let types = pasteboard.types ?? []
        guard !types.isEmpty else { return nil }
        if ConcealedTypes.shouldSkip(types: types) { return nil }

        // 1. Files
        if types.contains(.fileURL) {
            let urls = pasteboard.readObjects(forClasses: [NSURL.self],
                                              options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
            if !urls.isEmpty {
                let hash = Hashing.files(urls)
                let joined = urls.map(\.path).joined(separator: "\n")
                let preview = urls.map(\.lastPathComponent).joined(separator: ", ")
                let totalSize: Int64 = urls.reduce(0) { partial, url in
                    let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                    return partial + Int64(size)
                }
                return ClipItemDraft(
                    kind: .file,
                    contentHash: hash,
                    textContent: preview,
                    filePath: joined,
                    fileSizeBytes: totalSize == 0 ? nil : totalSize,
                    sourceBundleId: sourceBundleId,
                    sourceAppName: sourceAppName
                )
            }
        }

        // 2. Images (PNG/TIFF)
        if types.contains(.png) || types.contains(.tiff) {
            if let image = NSImage(pasteboard: pasteboard) {
                // Round-trip through PNG to get a stable byte representation for hashing.
                if let png = pngData(from: image) {
                    let hash = Hashing.data(png)
                    let paths = fileStore.writeImage(image, hash: hash)
                    return ClipItemDraft(
                        kind: .image,
                        contentHash: hash,
                        textContent: "Image (\(Int(image.size.width))×\(Int(image.size.height)))",
                        filePath: paths?.image.path,
                        thumbnailPath: paths?.thumb?.path,
                        fileSizeBytes: Int64(png.count),
                        sourceBundleId: sourceBundleId,
                        sourceAppName: sourceAppName
                    )
                }
            }
        }

        // 3. RTF
        if types.contains(.rtf), let data = pasteboard.data(forType: .rtf) {
            if let attributed = try? NSAttributedString(data: data, options: [
                .documentType: NSAttributedString.DocumentType.rtf
            ], documentAttributes: nil) {
                let plain = attributed.string
                let hash = Hashing.data(data)
                let url = fileStore.writeAttributedString(attributed, hash: hash)
                return ClipItemDraft(
                    kind: .rtf,
                    contentHash: hash,
                    textContent: plain,
                    filePath: url?.path,
                    fileSizeBytes: Int64(data.count),
                    sourceBundleId: sourceBundleId,
                    sourceAppName: sourceAppName
                )
            }
        }

        // 4. HTML
        if types.contains(.html), let data = pasteboard.data(forType: .html) {
            let html = String(data: data, encoding: .utf8) ?? ""
            let plain: String
            if let attributed = try? NSAttributedString(data: data, options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ], documentAttributes: nil) {
                plain = attributed.string
            } else {
                plain = html
            }
            let hash = Hashing.text(html)
            return ClipItemDraft(
                kind: .html,
                contentHash: hash,
                textContent: plain,
                htmlSource: html,
                sourceBundleId: sourceBundleId,
                sourceAppName: sourceAppName
            )
        }

        // 5. Plain text (further classified)
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            let hash = Hashing.text(text)
            if MarkdownDetector.isMarkdown(text) {
                return ClipItemDraft(
                    kind: .markdown,
                    contentHash: hash,
                    textContent: text,
                    sourceBundleId: sourceBundleId,
                    sourceAppName: sourceAppName
                )
            }
            if let lang = LanguageDetector.detect(text) {
                return ClipItemDraft(
                    kind: .code,
                    contentHash: hash,
                    textContent: text,
                    detectedLanguage: lang.rawValue,
                    sourceBundleId: sourceBundleId,
                    sourceAppName: sourceAppName
                )
            }
            return ClipItemDraft(
                kind: .text,
                contentHash: hash,
                textContent: text,
                sourceBundleId: sourceBundleId,
                sourceAppName: sourceAppName
            )
        }

        return nil
    }

    private func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
