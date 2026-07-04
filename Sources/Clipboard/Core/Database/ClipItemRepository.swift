import Combine
import Foundation

/// All DB access lives here. Emits `changesPublisher` on any mutation.
public final class ClipItemRepository {
    public let database: Database
    public let fileStore: FileStore

    private let changesSubject = PassthroughSubject<Void, Never>()
    public var changesPublisher: AnyPublisher<Void, Never> { changesSubject.eraseToAnyPublisher() }

    public init(database: Database, fileStore: FileStore) {
        self.database = database
        self.fileStore = fileStore
    }

    // MARK: - Insert / dedup

    @discardableResult
    public func insertOrBump(_ draft: ClipItemDraft) throws -> Int64 {
        try database.sqlite.sync { conn -> Int64 in
            let now = Date().timeIntervalSince1970
            // Try find existing by hash.
            let existing = try conn.query(
                "SELECT id, use_count FROM clip_items WHERE content_hash = ? LIMIT 1;",
                [.text(draft.contentHash)]
            ) { stmt in (stmt.int64(0), stmt.int(1)) }

            if let (id, useCount) = existing.first {
                try conn.execute(
                    "UPDATE clip_items SET last_used_at = ?, use_count = ? WHERE id = ?;",
                    [.real(now), .integer(Int64(useCount + 1)), .integer(id)]
                )
                self.changesSubject.send()
                return id
            }

            try conn.execute("""
                INSERT INTO clip_items (
                    kind, content_hash, text_content, html_source, detected_language,
                    file_path, thumbnail_path, file_size_bytes,
                    source_bundle_id, source_app_name,
                    is_pinned, is_favorited, created_at, last_used_at, use_count
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """, [
                .text(draft.kind.rawValue),
                .text(draft.contentHash),
                SQLValue.from(draft.textContent),
                SQLValue.from(draft.htmlSource),
                SQLValue.from(draft.detectedLanguage),
                SQLValue.from(draft.filePath),
                SQLValue.from(draft.thumbnailPath),
                SQLValue.from(draft.fileSizeBytes),
                SQLValue.from(draft.sourceBundleId),
                SQLValue.from(draft.sourceAppName),
                .bool(false),
                .bool(false),
                .real(now),
                .real(now),
                .integer(1),
            ])
            let newID = conn.lastInsertRowID
            self.changesSubject.send()
            return newID
        }
    }

    // MARK: - Fetch

    public func recent(limit: Int = 200) throws -> [ClipItem] {
        try database.sqlite.sync { conn in
            try conn.query(
                "\(ClipItem.selectAll) ORDER BY is_pinned DESC, last_used_at DESC LIMIT ?;",
                [.integer(Int64(limit))]
            ) { ClipItem(row: $0) }
        }
    }

    public func favorites(limit: Int = 200) throws -> [ClipItem] {
        try database.sqlite.sync { conn in
            try conn.query(
                "\(ClipItem.selectAll) WHERE is_favorited = 1 ORDER BY last_used_at DESC LIMIT ?;",
                [.integer(Int64(limit))]
            ) { ClipItem(row: $0) }
        }
    }

    public func pinned() throws -> [ClipItem] {
        try database.sqlite.sync { conn in
            try conn.query(
                "\(ClipItem.selectAll) WHERE is_pinned = 1 ORDER BY last_used_at DESC;"
            ) { ClipItem(row: $0) }
        }
    }

    public func fetch(id: Int64) throws -> ClipItem? {
        try database.sqlite.sync { conn in
            try conn.query(
                "\(ClipItem.selectAll) WHERE id = ? LIMIT 1;",
                [.integer(id)]
            ) { ClipItem(row: $0) }.first
        }
    }

    // MARK: - Composite fetch

    /// Central query that composes filter + optional FTS search into a single
    /// SQL statement. Callers pass any combination of kind / pinned / favorited
    /// / query; the DB does the work so older pinned/favorited/kind items are
    /// never lost by an in-memory truncation.
    public func fetch(
        kinds: Set<ClipItemKind>? = nil,
        pinnedOnly: Bool = false,
        favoritedOnly: Bool = false,
        query: String? = nil,
        limit: Int = 500
    ) throws -> [ClipItem] {
        let selectList = ClipItem.columns.map { "ci.\($0)" }.joined(separator: ", ")

        let ftsQuery: String? = {
            guard let raw = query else { return nil }
            let built = SearchQuery.build(from: raw)
            return built.isEmpty ? nil : built
        }()

        var sql = "SELECT \(selectList) FROM clip_items ci"
        if ftsQuery != nil {
            sql += " JOIN clip_items_fts f ON f.rowid = ci.id"
        }
        sql += " WHERE 1=1"

        var bindings: [SQLValue] = []
        if let q = ftsQuery {
            sql += " AND clip_items_fts MATCH ?"
            bindings.append(.text(q))
        }
        if pinnedOnly    { sql += " AND ci.is_pinned = 1" }
        if favoritedOnly { sql += " AND ci.is_favorited = 1" }
        if let kinds, !kinds.isEmpty {
            let placeholders = Array(repeating: "?", count: kinds.count).joined(separator: ", ")
            sql += " AND ci.kind IN (\(placeholders))"
            // Sorted for deterministic binding order across calls.
            for kind in kinds.map({ $0.rawValue }).sorted() {
                bindings.append(.text(kind))
            }
        }

        sql += " ORDER BY ci.is_pinned DESC,"
        if ftsQuery != nil { sql += " bm25(clip_items_fts) ASC," }
        sql += " ci.last_used_at DESC LIMIT ?;"
        bindings.append(.integer(Int64(limit)))

        return try database.sqlite.sync { conn in
            try conn.query(sql, bindings) { ClipItem(row: $0) }
        }
    }

    // MARK: - Search

    public func search(_ raw: String, limit: Int = 200) throws -> [ClipItem] {
        let query = SearchQuery.build(from: raw)
        guard !query.isEmpty else { return try recent(limit: limit) }
        return try database.sqlite.sync { conn in
            // FTS join. Column list matches ClipItem.columns, prefixed with the alias.
            let selectList = ClipItem.columns.map { "ci.\($0)" }.joined(separator: ", ")
            let sql = """
                SELECT \(selectList)
                FROM clip_items ci
                JOIN clip_items_fts f ON f.rowid = ci.id
                WHERE clip_items_fts MATCH ?
                ORDER BY ci.is_pinned DESC, bm25(clip_items_fts) ASC, ci.last_used_at DESC
                LIMIT ?;
            """
            return try conn.query(sql, [.text(query), .integer(Int64(limit))]) { ClipItem(row: $0) }
        }
    }

    // MARK: - Mutations

    public func setPinned(_ pinned: Bool, id: Int64) throws {
        try database.sqlite.sync { conn in
            try conn.execute(
                "UPDATE clip_items SET is_pinned = ? WHERE id = ?;",
                [.bool(pinned), .integer(id)]
            )
        }
        changesSubject.send()
    }

    public func setFavorited(_ favorited: Bool, id: Int64) throws {
        try database.sqlite.sync { conn in
            try conn.execute(
                "UPDATE clip_items SET is_favorited = ? WHERE id = ?;",
                [.bool(favorited), .integer(id)]
            )
        }
        changesSubject.send()
    }

    public func delete(id: Int64) throws {
        try database.sqlite.sync { conn in
            let hashes = try conn.query(
                "SELECT content_hash FROM clip_items WHERE id = ?;",
                [.integer(id)]
            ) { $0.text(0) ?? "" }
            try conn.execute("DELETE FROM clip_items WHERE id = ?;", [.integer(id)])
            for hash in hashes { self.fileStore.removeArtifacts(hash: hash) }
        }
        changesSubject.send()
    }

    public func deleteAll() throws {
        try database.sqlite.sync { conn in
            try conn.exec("DELETE FROM clip_items;")
            try conn.exec("DELETE FROM tags;")
            try conn.exec("VACUUM;")
        }
        changesSubject.send()
    }

    public func bumpUsage(id: Int64) throws {
        try database.sqlite.sync { conn in
            try conn.execute(
                "UPDATE clip_items SET last_used_at = ?, use_count = use_count + 1 WHERE id = ?;",
                [.real(Date().timeIntervalSince1970), .integer(id)]
            )
        }
        changesSubject.send()
    }

    // MARK: - Tags

    public func allTags() throws -> [Tag] {
        try database.sqlite.sync { conn in
            try conn.query("\(Tag.selectAll) ORDER BY name COLLATE NOCASE ASC;") { Tag(row: $0) }
        }
    }

    public func tags(forItem id: Int64) throws -> [Tag] {
        try database.sqlite.sync { conn in
            let selectList = Tag.columns.map { "t.\($0)" }.joined(separator: ", ")
            let sql = """
                SELECT \(selectList)
                FROM tags t
                JOIN item_tags it ON it.tag_id = t.id
                WHERE it.item_id = ?
                ORDER BY t.name COLLATE NOCASE ASC;
            """
            return try conn.query(sql, [.integer(id)]) { Tag(row: $0) }
        }
    }

    @discardableResult
    public func createOrGetTag(name: String, colorHex: String = "#8E8E93") throws -> Tag {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return try database.sqlite.sync { conn -> Tag in
            let existing = try conn.query(
                "\(Tag.selectAll) WHERE name = ? COLLATE NOCASE LIMIT 1;",
                [.text(trimmed)]
            ) { Tag(row: $0) }
            if let first = existing.first { return first }

            try conn.execute(
                "INSERT INTO tags(name, color_hex, created_at) VALUES (?, ?, ?);",
                [.text(trimmed), .text(colorHex), .real(Date().timeIntervalSince1970)]
            )
            let id = conn.lastInsertRowID
            return Tag(id: id, name: trimmed, colorHex: colorHex, createdAt: Date())
        }
    }

    public func attach(tag: Tag, to itemId: Int64) throws {
        guard let tagId = tag.id else { return }
        try database.sqlite.sync { conn in
            try conn.execute(
                "INSERT OR IGNORE INTO item_tags(item_id, tag_id) VALUES (?, ?);",
                [.integer(itemId), .integer(tagId)]
            )
        }
        changesSubject.send()
    }

    public func detach(tagId: Int64, from itemId: Int64) throws {
        try database.sqlite.sync { conn in
            try conn.execute(
                "DELETE FROM item_tags WHERE item_id = ? AND tag_id = ?;",
                [.integer(itemId), .integer(tagId)]
            )
        }
        changesSubject.send()
    }

    // MARK: - Cleanup

    @discardableResult
    public func performRetention(retentionDays: Int, maxItems: Int) throws -> [String] {
        try database.sqlite.sync { conn -> [String] in
            let cutoff = Date().addingTimeInterval(-Double(retentionDays) * 86400).timeIntervalSince1970

            let expired = try conn.query("""
                SELECT content_hash FROM clip_items
                WHERE is_pinned = 0 AND is_favorited = 0 AND created_at < ?;
            """, [.real(cutoff)]) { $0.text(0) ?? "" }
            try conn.execute("""
                DELETE FROM clip_items
                WHERE is_pinned = 0 AND is_favorited = 0 AND created_at < ?;
            """, [.real(cutoff)])

            let total = try conn.scalar("SELECT COUNT(*) FROM clip_items;") { $0.int(0) } ?? 0
            var overflow: [String] = []
            if total > maxItems {
                let excess = total - maxItems
                overflow = try conn.query("""
                    SELECT content_hash FROM clip_items
                    WHERE is_pinned = 0 AND is_favorited = 0
                    ORDER BY last_used_at ASC
                    LIMIT ?;
                """, [.integer(Int64(excess))]) { $0.text(0) ?? "" }
                try conn.execute("""
                    DELETE FROM clip_items
                    WHERE id IN (
                        SELECT id FROM clip_items
                        WHERE is_pinned = 0 AND is_favorited = 0
                        ORDER BY last_used_at ASC
                        LIMIT ?
                    );
                """, [.integer(Int64(excess))])
            }

            self.changesSubject.send()
            return expired + overflow
        }
    }
}
