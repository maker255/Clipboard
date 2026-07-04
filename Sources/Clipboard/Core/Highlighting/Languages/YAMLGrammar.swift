import Foundation

enum YAMLGrammar {
    static let rules: [TokenRule] = [
        TokenRule(#"#[^\n]*"#, .comment),

        TokenRule(#""[^"\n]*""#, .string),
        TokenRule(#"'[^'\n]*'"#, .string),

        // Keys
        TokenRule(#"(?m)^\s*[\w-]+(?=:)"#, .type),

        TokenRule(#"\b\d+(?:\.\d+)?\b"#, .number),

        TokenRule(#"\b(?:true|false|null|yes|no|on|off|~)\b"#, .keyword),
    ]
}
