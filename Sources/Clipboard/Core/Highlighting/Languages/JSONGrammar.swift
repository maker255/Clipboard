import Foundation

enum JSONGrammar {
    static let rules: [TokenRule] = [
        // Keys (quoted string followed by colon)
        TokenRule(#""(?:\\.|[^"\\\n])*"(?=\s*:)"#, .type),
        // Other strings
        TokenRule(#""(?:\\.|[^"\\\n])*""#, .string),
        // Numbers
        TokenRule(#"-?\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b"#, .number),
        // Keywords
        TokenRule(#"\b(?:true|false|null)\b"#, .keyword),
    ]
}
