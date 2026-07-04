import Foundation
import SQLite3

/// Thin Swift wrapper over sqlite3 C API. Replaces GRDB for the CLT-only build path.
///
/// All operations are serialized on an internal queue so callers can safely
/// share a single instance across threads.
public final class SQLiteDatabase {
    private var handle: OpaquePointer?
    private let queue = DispatchQueue(label: "com.local.clipboard.sqlite")

    // C string binding sentinels — sqlite headers define SQLITE_TRANSIENT/STATIC
    // as -1 / 0 casts to sqlite3_destructor_type. Reproduce in Swift.
    static let SQLITE_TRANSIENT = unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)
    static let SQLITE_STATIC    = unsafeBitCast(OpaquePointer(bitPattern:  0), to: sqlite3_destructor_type.self)

    // MARK: - Init

    public init(path: String) throws {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let rc = sqlite3_open_v2(path, &db, flags, nil)
        guard rc == SQLITE_OK, let db else {
            let msg = String(cString: sqlite3_errmsg(db))
            if db != nil { sqlite3_close_v2(db) }
            throw SQLiteError(code: rc, message: "open failed at \(path): \(msg)")
        }
        self.handle = db
    }

    public static func inMemory() throws -> SQLiteDatabase {
        try SQLiteDatabase(path: ":memory:")
    }

    deinit {
        if let handle { sqlite3_close_v2(handle) }
    }

    // MARK: - Queue serialization

    /// Serialize a block on the internal queue.
    public func sync<T>(_ block: (Connection) throws -> T) rethrows -> T {
        try queue.sync {
            try block(Connection(handle: handle!))
        }
    }

    /// Async variant (rarely useful — most callers want sync semantics).
    public func async(_ block: @escaping (Connection) -> Void) {
        queue.async { [weak self] in
            guard let self, let handle = self.handle else { return }
            block(Connection(handle: handle))
        }
    }

    // MARK: - Convenience passthroughs

    public func exec(_ sql: String) throws {
        try sync { try $0.exec(sql) }
    }

    public func execute(_ sql: String, _ bindings: [SQLValue] = []) throws {
        try sync { try $0.execute(sql, bindings) }
    }

    @discardableResult
    public func lastInsertRowID() -> Int64 {
        sync { $0.lastInsertRowID }
    }
}

public struct SQLiteError: Error, CustomStringConvertible {
    public let code: Int32
    public let message: String
    public var description: String { "SQLiteError(\(code)): \(message)" }
}

// MARK: - Connection handle wrapper

/// A borrowed connection exposed inside a `sync` block. Provides prepare/exec/
/// transaction primitives.
public struct Connection {
    public let handle: OpaquePointer

    /// Multi-statement exec via sqlite3_exec. No parameter binding.
    public func exec(_ sql: String) throws {
        var errmsg: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(handle, sql, nil, nil, &errmsg)
        if rc != SQLITE_OK {
            let msg = errmsg.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(errmsg)
            throw SQLiteError(code: rc, message: msg)
        }
    }

    /// Prepare a statement, bind parameters, and step through results, invoking `row` for each `SQLITE_ROW`.
    public func query<T>(_ sql: String,
                         _ bindings: [SQLValue] = [],
                         row: (Statement) throws -> T) throws -> [T] {
        let stmt = try Statement.prepare(handle: handle, sql: sql, bindings: bindings)
        defer { stmt.finalize() }
        var results: [T] = []
        while true {
            let step = sqlite3_step(stmt.stmt)
            if step == SQLITE_ROW {
                results.append(try row(stmt))
            } else if step == SQLITE_DONE {
                break
            } else {
                throw SQLiteError(code: step, message: String(cString: sqlite3_errmsg(handle)))
            }
        }
        return results
    }

    /// Prepare, bind, step-to-done. Returns rows changed.
    @discardableResult
    public func execute(_ sql: String, _ bindings: [SQLValue] = []) throws -> Int32 {
        let stmt = try Statement.prepare(handle: handle, sql: sql, bindings: bindings)
        defer { stmt.finalize() }
        let step = sqlite3_step(stmt.stmt)
        guard step == SQLITE_DONE else {
            throw SQLiteError(code: step, message: String(cString: sqlite3_errmsg(handle)))
        }
        return sqlite3_changes(handle)
    }

    /// Fetch a single scalar value (first column of first row).
    public func scalar<T>(_ sql: String, _ bindings: [SQLValue] = [], read: (Statement) -> T?) throws -> T? {
        let stmt = try Statement.prepare(handle: handle, sql: sql, bindings: bindings)
        defer { stmt.finalize() }
        if sqlite3_step(stmt.stmt) == SQLITE_ROW {
            return read(stmt)
        }
        return nil
    }

    public var lastInsertRowID: Int64 {
        sqlite3_last_insert_rowid(handle)
    }

    /// BEGIN … COMMIT wrapper. Rolls back on throw.
    public func transaction<T>(_ block: (Connection) throws -> T) throws -> T {
        try exec("BEGIN IMMEDIATE;")
        do {
            let result = try block(self)
            try exec("COMMIT;")
            return result
        } catch {
            try? exec("ROLLBACK;")
            throw error
        }
    }
}

// MARK: - Statement + row reading

public struct Statement {
    let stmt: OpaquePointer

    static func prepare(handle: OpaquePointer, sql: String, bindings: [SQLValue]) throws -> Statement {
        var s: OpaquePointer?
        let rc = sqlite3_prepare_v2(handle, sql, -1, &s, nil)
        guard rc == SQLITE_OK, let s else {
            throw SQLiteError(code: rc, message: String(cString: sqlite3_errmsg(handle)))
        }
        for (i, value) in bindings.enumerated() {
            let position = Int32(i + 1)
            value.bind(to: s, at: position)
        }
        return Statement(stmt: s)
    }

    func finalize() {
        sqlite3_finalize(stmt)
    }

    // Column readers (0-indexed).
    public func isNull(_ column: Int32) -> Bool {
        sqlite3_column_type(stmt, column) == SQLITE_NULL
    }

    public func text(_ column: Int32) -> String? {
        guard let ptr = sqlite3_column_text(stmt, column) else { return nil }
        return String(cString: ptr)
    }

    public func int(_ column: Int32) -> Int {
        Int(sqlite3_column_int64(stmt, column))
    }

    public func int64(_ column: Int32) -> Int64 {
        sqlite3_column_int64(stmt, column)
    }

    public func int64Optional(_ column: Int32) -> Int64? {
        isNull(column) ? nil : sqlite3_column_int64(stmt, column)
    }

    public func double(_ column: Int32) -> Double {
        sqlite3_column_double(stmt, column)
    }

    public func bool(_ column: Int32) -> Bool {
        sqlite3_column_int(stmt, column) != 0
    }

    public func date(_ column: Int32) -> Date {
        Date(timeIntervalSince1970: sqlite3_column_double(stmt, column))
    }
}

// MARK: - Parameter binding values

public enum SQLValue {
    case null
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob(Data)

    public static func bool(_ b: Bool) -> SQLValue { .integer(b ? 1 : 0) }
    public static func date(_ d: Date) -> SQLValue { .real(d.timeIntervalSince1970) }

    public static func optional<T>(_ value: T?, _ wrap: (T) -> SQLValue) -> SQLValue {
        value.map(wrap) ?? .null
    }

    fileprivate func bind(to stmt: OpaquePointer, at position: Int32) {
        switch self {
        case .null:
            sqlite3_bind_null(stmt, position)
        case .integer(let i):
            sqlite3_bind_int64(stmt, position, i)
        case .real(let d):
            sqlite3_bind_double(stmt, position, d)
        case .text(let s):
            sqlite3_bind_text(stmt, position, s, -1, SQLiteDatabase.SQLITE_TRANSIENT)
        case .blob(let data):
            data.withUnsafeBytes { raw in
                _ = sqlite3_bind_blob(stmt, position, raw.baseAddress, Int32(raw.count),
                                      SQLiteDatabase.SQLITE_TRANSIENT)
            }
        }
    }
}

// MARK: - Convenience initializers for common Swift types

extension SQLValue: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral,
                    ExpressibleByFloatLiteral, ExpressibleByNilLiteral, ExpressibleByBooleanLiteral {
    public init(stringLiteral value: String)   { self = .text(value) }
    public init(integerLiteral value: Int)     { self = .integer(Int64(value)) }
    public init(floatLiteral value: Double)    { self = .real(value) }
    public init(nilLiteral: ())                { self = .null }
    public init(booleanLiteral value: Bool)    { self = .bool(value) }
}

// String? / Int64? / Date? → SQLValue directly
public extension SQLValue {
    static func from(_ value: String?)  -> SQLValue { value.map { .text($0) } ?? .null }
    static func from(_ value: Int64?)   -> SQLValue { value.map { .integer($0) } ?? .null }
    static func from(_ value: Int?)     -> SQLValue { value.map { .integer(Int64($0)) } ?? .null }
    static func from(_ value: Date?)    -> SQLValue { value.map { .real($0.timeIntervalSince1970) } ?? .null }
    static func from(_ value: Bool)     -> SQLValue { .bool(value) }
    static func from(_ value: Data?)    -> SQLValue { value.map { .blob($0) } ?? .null }
}
