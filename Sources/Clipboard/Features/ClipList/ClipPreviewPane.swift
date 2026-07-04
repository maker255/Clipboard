import AppKit
import SwiftUI

public struct ClipPreviewPane: View {
    public let item: ClipItem?

    public init(item: ClipItem?) { self.item = item }

    public var body: some View {
        Group {
            if let item {
                content(for: item)
            } else {
                empty
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }

    @ViewBuilder private func content(for item: ClipItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header(item)
            Divider().opacity(0.4)
            preview(item)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Divider().opacity(0.4)
            footer(item)
        }
    }

    // MARK: - Header

    @ViewBuilder private func header(_ item: ClipItem) -> some View {
        HStack(spacing: 8) {
            Text(kindLabel(item))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            if let lang = item.detectedLanguage {
                Text(lang.uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())
            }
            Spacer()
            if item.isPinned {
                Image(systemName: "pin.fill").font(.system(size: 10)).foregroundStyle(.orange)
            }
            if item.isFavorited {
                Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(.yellow)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Body

    @ViewBuilder private func preview(_ item: ClipItem) -> some View {
        switch item.kind {
        case .image:
            imagePreview(item)
        case .file:
            filePreview(item)
        case .html:
            attributedHTMLPreview(item)
        case .rtf:
            attributedRTFPreview(item)
        case .markdown:
            markdownPreview(item)
        case .code:
            codePreview(item)
        case .text:
            textPreview(item)
        }
    }

    @ViewBuilder private func imagePreview(_ item: ClipItem) -> some View {
        if let path = item.filePath, let img = NSImage(contentsOfFile: path) {
            ScrollView([.vertical, .horizontal], showsIndicators: true) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(14)
            }
        } else {
            emptyMessage("Image not available")
        }
    }

    @ViewBuilder private func filePreview(_ item: ClipItem) -> some View {
        let paths = (item.filePath ?? "").components(separatedBy: "\n").filter { !$0.isEmpty }
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(paths, id: \.self) { p in
                    HStack(spacing: 10) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: p))
                            .resizable().frame(width: 24, height: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text((p as NSString).lastPathComponent)
                                .font(.system(size: 13, weight: .medium))
                            Text(p)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private func codePreview(_ item: ClipItem) -> some View {
        let text = item.textContent ?? ""
        let lang = item.detectedLanguage.flatMap(CodeLanguage.init(rawValue:))
        let attributed = SyntaxHighlighter.highlight(text, language: lang)
        ScrollView {
            Text(attributed)
                .textSelection(.enabled)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
        }
    }

    @ViewBuilder private func markdownPreview(_ item: ClipItem) -> some View {
        let text = item.textContent ?? ""
        let attributed = (try? AttributedString(markdown: text, options: .init(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        ))) ?? AttributedString(text)
        ScrollView {
            Text(attributed)
                .textSelection(.enabled)
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
        }
    }

    @ViewBuilder private func textPreview(_ item: ClipItem) -> some View {
        ScrollView {
            Text(item.textContent ?? "")
                .textSelection(.enabled)
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
        }
    }

    @ViewBuilder private func attributedHTMLPreview(_ item: ClipItem) -> some View {
        if let html = item.htmlSource,
           let data = html.data(using: .utf8),
           let ns = try? NSAttributedString(data: data, options: [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
           ], documentAttributes: nil) {
            let s = try? AttributedString(ns, including: \.appKit)
            ScrollView {
                Text(s ?? AttributedString(ns.string))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            }
        } else {
            textPreview(item)
        }
    }

    @ViewBuilder private func attributedRTFPreview(_ item: ClipItem) -> some View {
        if let ns = FileStore.shared.readAttributedString(hash: item.contentHash) {
            let s = try? AttributedString(ns, including: \.appKit)
            ScrollView {
                Text(s ?? AttributedString(ns.string))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            }
        } else {
            textPreview(item)
        }
    }

    // MARK: - Footer

    @ViewBuilder private func footer(_ item: ClipItem) -> some View {
        HStack(spacing: 12) {
            if let name = item.sourceAppName {
                Label(name, systemImage: "app.dashed")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            if let size = item.fileSizeBytes {
                Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text(Self.absoluteFormatter.string(from: item.createdAt))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private func kindLabel(_ item: ClipItem) -> String {
        switch item.kind {
        case .text: return "Text"
        case .image: return "Image"
        case .file: return "File"
        case .html: return "HTML"
        case .rtf: return "Rich Text"
        case .markdown: return "Markdown"
        case .code: return "Code"
        }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("Select a clip")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyMessage(_ msg: String) -> some View {
        Text(msg).foregroundStyle(.secondary).padding()
    }

    private static let absoluteFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}
