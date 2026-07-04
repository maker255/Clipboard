import Foundation

/// Turns a raw user query into a safe FTS5 MATCH string.
///
/// - Splits on whitespace.
/// - Wraps each token in double-quotes to escape FTS operators.
/// - Appends `*` to the last token for prefix matching (Raycast/Spotlight feel).
public enum SearchQuery {
    public static func build(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let tokens = trimmed
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }

        guard !tokens.isEmpty else { return "" }

        var pieces: [String] = []
        for (i, token) in tokens.enumerated() {
            let escaped = token.replacingOccurrences(of: "\"", with: "\"\"")
            if i == tokens.count - 1 {
                pieces.append("\"\(escaped)\"*")
            } else {
                pieces.append("\"\(escaped)\"")
            }
        }
        return pieces.joined(separator: " ")
    }
}
