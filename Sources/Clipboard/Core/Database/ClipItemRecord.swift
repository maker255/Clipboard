import Foundation

public enum ClipItemKind: String, Codable, CaseIterable {
    case text
    case image
    case file
    case html
    case rtf
    case markdown
    case code
}

/// Domain model. Contents mirror the `clip_items` table columns exactly.
public struct ClipItem: Identifiable, Hashable {
    public var id: Int64?
    public var kind: ClipItemKind
    public var contentHash: String
    public var textContent: String?
    public var htmlSource: String?
    public var detectedLanguage: String?
    public var filePath: String?
    public var thumbnailPath: String?
    public var fileSizeBytes: Int64?
    public var sourceBundleId: String?
    public var sourceAppName: String?
    public var isPinned: Bool
    public var isFavorited: Bool
    public var createdAt: Date
    public var lastUsedAt: Date
    public var useCount: Int

    public init(
        id: Int64? = nil,
        kind: ClipItemKind,
        contentHash: String,
        textContent: String? = nil,
        htmlSource: String? = nil,
        detectedLanguage: String? = nil,
        filePath: String? = nil,
        thumbnailPath: String? = nil,
        fileSizeBytes: Int64? = nil,
        sourceBundleId: String? = nil,
        sourceAppName: String? = nil,
        isPinned: Bool = false,
        isFavorited: Bool = false,
        createdAt: Date = Date(),
        lastUsedAt: Date = Date(),
        useCount: Int = 0
    ) {
        self.id = id
        self.kind = kind
        self.contentHash = contentHash
        self.textContent = textContent
        self.htmlSource = htmlSource
        self.detectedLanguage = detectedLanguage
        self.filePath = filePath
        self.thumbnailPath = thumbnailPath
        self.fileSizeBytes = fileSizeBytes
        self.sourceBundleId = sourceBundleId
        self.sourceAppName = sourceAppName
        self.isPinned = isPinned
        self.isFavorited = isFavorited
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.useCount = useCount
    }

    /// Ordered list of all columns for SELECT * queries — keep in sync with
    /// `init(row:)` and the table definition in Migrations.
    public static let columns: [String] = [
        "id", "kind", "content_hash", "text_content", "html_source",
        "detected_language", "file_path", "thumbnail_path", "file_size_bytes",
        "source_bundle_id", "source_app_name", "is_pinned", "is_favorited",
        "created_at", "last_used_at", "use_count"
    ]

    public static let selectAll = "SELECT " + columns.joined(separator: ", ") + " FROM clip_items"

    /// Positional row hydration. Column order must match `columns` above.
    public init(row stmt: Statement) {
        self.id                = stmt.int64(0)
        let kindRaw            = stmt.text(1) ?? "text"
        self.kind              = ClipItemKind(rawValue: kindRaw) ?? .text
        self.contentHash       = stmt.text(2) ?? ""
        self.textContent       = stmt.text(3)
        self.htmlSource        = stmt.text(4)
        self.detectedLanguage  = stmt.text(5)
        self.filePath          = stmt.text(6)
        self.thumbnailPath     = stmt.text(7)
        self.fileSizeBytes     = stmt.int64Optional(8)
        self.sourceBundleId    = stmt.text(9)
        self.sourceAppName     = stmt.text(10)
        self.isPinned          = stmt.bool(11)
        self.isFavorited       = stmt.bool(12)
        self.createdAt         = stmt.date(13)
        self.lastUsedAt        = stmt.date(14)
        self.useCount          = stmt.int(15)
    }
}

/// A payload produced by `PasteboardReader` before persistence.
public struct ClipItemDraft {
    public var kind: ClipItemKind
    public var contentHash: String
    public var textContent: String?
    public var htmlSource: String?
    public var detectedLanguage: String?
    public var filePath: String?
    public var thumbnailPath: String?
    public var fileSizeBytes: Int64?
    public var sourceBundleId: String?
    public var sourceAppName: String?

    public init(
        kind: ClipItemKind,
        contentHash: String,
        textContent: String? = nil,
        htmlSource: String? = nil,
        detectedLanguage: String? = nil,
        filePath: String? = nil,
        thumbnailPath: String? = nil,
        fileSizeBytes: Int64? = nil,
        sourceBundleId: String? = nil,
        sourceAppName: String? = nil
    ) {
        self.kind = kind
        self.contentHash = contentHash
        self.textContent = textContent
        self.htmlSource = htmlSource
        self.detectedLanguage = detectedLanguage
        self.filePath = filePath
        self.thumbnailPath = thumbnailPath
        self.fileSizeBytes = fileSizeBytes
        self.sourceBundleId = sourceBundleId
        self.sourceAppName = sourceAppName
    }
}
