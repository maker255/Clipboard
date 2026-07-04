import Foundation

enum SwiftGrammar {
    static let rules: [TokenRule] = [
        // Comments first — they trump everything else on the same range.
        TokenRule(#"//[^\n]*"#, .comment),
        TokenRule(#"/\*[\s\S]*?\*/"#, .comment),

        // Strings
        TokenRule(##"""[\s\S]*?""""##, .string),   // multi-line """..."""
        TokenRule(#""(?:\\.|[^"\\\n])*""#, .string),

        // Numbers
        TokenRule(#"\b(?:0x[0-9A-Fa-f_]+|0b[01_]+|0o[0-7_]+|\d[\d_]*(?:\.[\d_]+)?(?:[eE][+-]?\d+)?)\b"#, .number),

        // Types (rough): PascalCase identifiers
        TokenRule(#"\b[A-Z][A-Za-z0-9_]*\b"#, .type),

        // Keywords
        TokenRule(#"""
        \b(?:associatedtype|class|deinit|enum|extension|fileprivate|func|import|init|inout|internal|let|open|operator|private|protocol|public|rethrows|static|struct|subscript|typealias|var|break|case|continue|default|defer|do|else|fallthrough|for|guard|if|in|repeat|return|switch|throw|throws|try|where|while|as|Any|catch|false|is|nil|super|self|Self|true|async|await|actor|any|some)\b
        """#, .keyword),
    ]
}
