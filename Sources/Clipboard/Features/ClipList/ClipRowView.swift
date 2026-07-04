import AppKit
import SwiftUI

public struct ClipRowView: View {
    public let item: ClipItem
    public let isSelected: Bool

    public init(item: ClipItem, isSelected: Bool) {
        self.item = item
        self.isSelected = isSelected
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            leading
                .frame(width: 32, height: 32)
                .background(iconBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 4)
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.orange)
                    }
                    if item.isFavorited {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.yellow)
                    }
                }
                HStack(spacing: 6) {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(relativeTime)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.20) : Color.clear)
        )
        .contentShape(Rectangle())
    }

    // MARK: - Content pieces

    @ViewBuilder private var leading: some View {
        switch item.kind {
        case .image:
            if let path = item.thumbnailPath ?? item.filePath, let img = NSImage(contentsOfFile: path) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "photo").foregroundStyle(.secondary)
            }
        case .file:
            Image(systemName: "doc.on.doc")
                .foregroundStyle(.secondary)
        case .code, .markdown:
            Image(systemName: item.kind == .markdown
                  ? "text.alignleft"
                  : "chevron.left.forwardslash.chevron.right")
                .foregroundStyle(.secondary)
        case .html:
            Image(systemName: "safari").foregroundStyle(.secondary)
        case .rtf:
            Image(systemName: "textformat").foregroundStyle(.secondary)
        case .text:
            Image(systemName: "text.quote").foregroundStyle(.secondary)
        }
    }

    private var iconBackground: Color {
        switch item.kind {
        case .image:      return Color.pink.opacity(0.15)
        case .file:       return Color.blue.opacity(0.15)
        case .code:       return Color.purple.opacity(0.15)
        case .markdown:   return Color.purple.opacity(0.15)
        case .html:       return Color.orange.opacity(0.15)
        case .rtf:        return Color.teal.opacity(0.15)
        case .text:       return Color.gray.opacity(0.15)
        }
    }

    private var title: String {
        switch item.kind {
        case .image:
            return item.textContent ?? "Image"
        case .file:
            return item.textContent ?? "Files"
        default:
            if let t = item.textContent {
                return String(t.split(separator: "\n").first ?? Substring(t))
            }
            return item.kind.rawValue.capitalized
        }
    }

    private var subtitle: String {
        switch item.kind {
        case .code:
            let lang = item.detectedLanguage.map { "\($0.capitalized) · " } ?? ""
            return lang + (item.sourceAppName ?? "Code")
        default:
            return item.sourceAppName ?? item.kind.rawValue.capitalized
        }
    }

    private var relativeTime: String {
        Self.formatter.localizedString(for: item.lastUsedAt, relativeTo: Date())
    }

    private static let formatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()
}
