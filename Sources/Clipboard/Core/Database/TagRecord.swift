import Foundation

public struct Tag: Identifiable, Hashable {
    public var id: Int64?
    public var name: String
    public var colorHex: String
    public var createdAt: Date

    public init(id: Int64? = nil, name: String, colorHex: String = "#8E8E93", createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
    }

    public static let columns: [String] = ["id", "name", "color_hex", "created_at"]
    public static let selectAll = "SELECT " + columns.joined(separator: ", ") + " FROM tags"

    public init(row stmt: Statement) {
        self.id        = stmt.int64(0)
        self.name      = stmt.text(1) ?? ""
        self.colorHex  = stmt.text(2) ?? "#8E8E93"
        self.createdAt = stmt.date(3)
    }
}
