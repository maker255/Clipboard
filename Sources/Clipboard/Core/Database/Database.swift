import Foundation

/// Facade over the raw SQLite handle. Owns migrations + pragmas.
public final class Database {
    public let sqlite: SQLiteDatabase

    public init(sqlite: SQLiteDatabase) throws {
        self.sqlite = sqlite
        try sqlite.sync { conn in
            try conn.exec("PRAGMA foreign_keys = ON;")
            try conn.exec("PRAGMA journal_mode = WAL;")
            try conn.exec("PRAGMA synchronous = NORMAL;")
            try conn.exec("PRAGMA busy_timeout = 5000;")
        }
        try Migrations.run(on: sqlite)
    }

    public static func makeDefault(fileStore: FileStore) throws -> Database {
        let db = try SQLiteDatabase(path: fileStore.databaseURL.path)
        return try Database(sqlite: db)
    }

    public static func makeInMemory() throws -> Database {
        let db = try SQLiteDatabase.inMemory()
        return try Database(sqlite: db)
    }
}
