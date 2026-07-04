import Foundation

/// Idempotent migration runner. Uses a `schema_version` PRAGMA-like table to
/// track applied migrations. This replaces GRDB's DatabaseMigrator.
enum Migrations {
    static let all: [(name: String, sql: String)] = [
        ("v1_initial", v1)
    ]

    static func run(on db: SQLiteDatabase) throws {
        try db.sync { conn in
            try conn.exec("""
                CREATE TABLE IF NOT EXISTS schema_migrations (
                    name TEXT PRIMARY KEY,
                    applied_at REAL NOT NULL
                );
            """)

            let applied = try conn.query("SELECT name FROM schema_migrations") { stmt in
                stmt.text(0) ?? ""
            }
            let appliedSet = Set(applied)

            for migration in all where !appliedSet.contains(migration.name) {
                try conn.transaction { c in
                    try c.exec(migration.sql)
                    try c.execute(
                        "INSERT INTO schema_migrations(name, applied_at) VALUES (?, ?);",
                        [.text(migration.name), .real(Date().timeIntervalSince1970)]
                    )
                }
                Log.database.info("Applied migration \(migration.name)")
            }
        }
    }

    // MARK: - v1 schema

    private static let v1 = """
    CREATE TABLE clip_items (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        kind              TEXT    NOT NULL,
        content_hash      TEXT    NOT NULL,
        text_content      TEXT,
        html_source       TEXT,
        detected_language TEXT,
        file_path         TEXT,
        thumbnail_path    TEXT,
        file_size_bytes   INTEGER,
        source_bundle_id  TEXT,
        source_app_name   TEXT,
        is_pinned         INTEGER NOT NULL DEFAULT 0,
        is_favorited      INTEGER NOT NULL DEFAULT 0,
        created_at        REAL    NOT NULL,
        last_used_at      REAL    NOT NULL,
        use_count         INTEGER NOT NULL DEFAULT 0
    );

    CREATE UNIQUE INDEX ux_clip_items_hash    ON clip_items(content_hash);
    CREATE INDEX ix_clip_items_last_used      ON clip_items(last_used_at DESC);
    CREATE INDEX ix_clip_items_pinned         ON clip_items(is_pinned)    WHERE is_pinned = 1;
    CREATE INDEX ix_clip_items_favorited      ON clip_items(is_favorited) WHERE is_favorited = 1;
    CREATE INDEX ix_clip_items_kind           ON clip_items(kind);

    CREATE TABLE tags (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT NOT NULL UNIQUE COLLATE NOCASE,
        color_hex  TEXT NOT NULL DEFAULT '#8E8E93',
        created_at REAL NOT NULL
    );

    CREATE TABLE item_tags (
        item_id INTEGER NOT NULL REFERENCES clip_items(id) ON DELETE CASCADE,
        tag_id  INTEGER NOT NULL REFERENCES tags(id)       ON DELETE CASCADE,
        PRIMARY KEY (item_id, tag_id)
    );
    CREATE INDEX ix_item_tags_tag ON item_tags(tag_id);

    CREATE VIRTUAL TABLE clip_items_fts USING fts5(
        text_content, html_source, detected_language, source_app_name,
        content='clip_items', content_rowid='id',
        tokenize='porter unicode61 remove_diacritics 2'
    );

    CREATE TRIGGER clip_items_ai AFTER INSERT ON clip_items BEGIN
        INSERT INTO clip_items_fts(rowid, text_content, html_source, detected_language, source_app_name)
        VALUES (new.id, new.text_content, new.html_source, new.detected_language, new.source_app_name);
    END;

    CREATE TRIGGER clip_items_ad AFTER DELETE ON clip_items BEGIN
        INSERT INTO clip_items_fts(clip_items_fts, rowid, text_content, html_source, detected_language, source_app_name)
        VALUES ('delete', old.id, old.text_content, old.html_source, old.detected_language, old.source_app_name);
    END;

    CREATE TRIGGER clip_items_au AFTER UPDATE ON clip_items BEGIN
        INSERT INTO clip_items_fts(clip_items_fts, rowid, text_content, html_source, detected_language, source_app_name)
        VALUES ('delete', old.id, old.text_content, old.html_source, old.detected_language, old.source_app_name);
        INSERT INTO clip_items_fts(rowid, text_content, html_source, detected_language, source_app_name)
        VALUES (new.id, new.text_content, new.html_source, new.detected_language, new.source_app_name);
    END;
    """
}
