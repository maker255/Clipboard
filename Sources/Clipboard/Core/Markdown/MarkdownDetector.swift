import Foundation

/// Heuristic: is this text most likely intended as Markdown?
///
/// We use a small scored signal set. A single `#` isn't enough; we need
/// two or more distinct markdown constructs.
public enum MarkdownDetector {
    public static func isMarkdown(_ text: String) -> Bool { score(text) >= 2 }

    public static func score(_ text: String) -> Int {
        var s = 0
        // Headings
        if text.range(of: #"(?m)^\s{0,3}#{1,6}\s+\S"#, options: .regularExpression) != nil { s += 1 }
        // Bulleted or ordered lists
        if text.range(of: #"(?m)^\s{0,3}([-*+]|\d+\.)\s+\S"#, options: .regularExpression) != nil { s += 1 }
        // Fenced code blocks
        if text.contains("```") { s += 2 }
        // Bold/italic
        if text.range(of: #"\*\*[^*\n]+\*\*"#, options: .regularExpression) != nil { s += 1 }
        // Inline code
        if text.range(of: #"`[^`\n]+`"#, options: .regularExpression) != nil { s += 1 }
        // Links
        if text.range(of: #"\[[^\]\n]+\]\([^)\s]+\)"#, options: .regularExpression) != nil { s += 1 }
        // Blockquotes
        if text.range(of: #"(?m)^\s{0,3}>\s+"#, options: .regularExpression) != nil { s += 1 }
        return s
    }
}
