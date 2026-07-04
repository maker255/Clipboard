import Foundation

enum HTMLGrammar {
    static let rules: [TokenRule] = [
        TokenRule(#"<!--[\s\S]*?-->"#, .comment),

        // Attribute values
        TokenRule(#""[^"\n]*""#, .string),
        TokenRule(#"'[^'\n]*'"#, .string),

        // Tag names
        TokenRule(#"</?[A-Za-z][A-Za-z0-9-]*"#, .keyword),

        // Attribute names (word=)
        TokenRule(#"\b[a-zA-Z_-]+(?==)"#, .type),
    ]
}
