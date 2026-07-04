import AppKit
import Foundation

/// Writes a `ClipItem` back onto a pasteboard prior to sending ⌘V.
///
/// Uses the item's original kind + on-disk artifacts. RTF/HTML/image paste
/// preserves rich formatting when the target app supports it.
public enum PasteboardWriter {
    public static func write(_ item: ClipItem,
                             preferPlainText: Bool = false,
                             to pasteboard: NSPasteboard = .general,
                             fileStore: FileStore = .shared) {
        pasteboard.clearContents()

        switch item.kind {
        case .text, .markdown, .code:
            if let text = item.textContent { pasteboard.setString(text, forType: .string) }

        case .html:
            if !preferPlainText, let html = item.htmlSource,
               let data = html.data(using: .utf8) {
                pasteboard.setData(data, forType: .html)
            }
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }

        case .rtf:
            if !preferPlainText,
               let attributed = fileStore.readAttributedString(hash: item.contentHash),
               let rtf = try? attributed.data(
                    from: NSRange(location: 0, length: attributed.length),
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
               ) {
                pasteboard.setData(rtf, forType: .rtf)
            }
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }

        case .image:
            if let path = item.filePath, let image = NSImage(contentsOfFile: path) {
                pasteboard.writeObjects([image])
            }

        case .file:
            if let joined = item.filePath {
                let paths = joined.components(separatedBy: "\n")
                let urls = paths.compactMap { URL(fileURLWithPath: $0) as NSURL }
                if !urls.isEmpty { pasteboard.writeObjects(urls) }
            }
        }
    }
}
