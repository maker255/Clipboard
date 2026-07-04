import Foundation

public struct ItemTag {
    public var itemId: Int64
    public var tagId: Int64

    public init(itemId: Int64, tagId: Int64) {
        self.itemId = itemId
        self.tagId = tagId
    }
}
