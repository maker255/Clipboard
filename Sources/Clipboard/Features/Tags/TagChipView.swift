import SwiftUI

public struct TagChipView: View {
    public let tag: Tag
    public var onRemove: (() -> Void)?

    public init(tag: Tag, onRemove: (() -> Void)? = nil) {
        self.tag = tag
        self.onRemove = onRemove
    }

    public var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: tag.colorHex) ?? .gray)
                .frame(width: 6, height: 6)
            Text(tag.name)
                .font(.system(size: 11, weight: .medium))
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark").font(.system(size: 8))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(Color.secondary.opacity(0.12))
        )
    }
}

extension Color {
    /// Parse `#RRGGBB` or `#RRGGBBAA`.
    public init?(hex: String) {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        guard let value = UInt64(s, radix: 16) else { return nil }
        let r, g, b, a: Double
        switch s.count {
        case 6:
            r = Double((value >> 16) & 0xFF) / 255.0
            g = Double((value >>  8) & 0xFF) / 255.0
            b = Double( value        & 0xFF) / 255.0
            a = 1.0
        case 8:
            r = Double((value >> 24) & 0xFF) / 255.0
            g = Double((value >> 16) & 0xFF) / 255.0
            b = Double((value >>  8) & 0xFF) / 255.0
            a = Double( value        & 0xFF) / 255.0
        default: return nil
        }
        self.init(red: r, green: g, blue: b, opacity: a)
    }
}
