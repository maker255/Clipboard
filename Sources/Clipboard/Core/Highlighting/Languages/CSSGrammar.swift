import Foundation

enum CSSGrammar {
    static let rules: [TokenRule] = [
        TokenRule(#"/\*[\s\S]*?\*/"#, .comment),

        TokenRule(#""[^"\n]*""#, .string),
        TokenRule(#"'[^'\n]*'"#, .string),

        // Hex colors
        TokenRule(#"#[0-9A-Fa-f]{3,8}\b"#, .number),
        TokenRule(#"\b\d+(?:\.\d+)?(?:px|em|rem|%|vh|vw|s|ms|deg)?\b"#, .number),

        // Selectors leading with . # or :
        TokenRule(#"[.#][A-Za-z][\w-]*"#, .type),

        // At-rules
        TokenRule(#"@[A-Za-z-]+"#, .keyword),

        // Properties (word followed by colon inside a rule)
        TokenRule(#"(?m)^\s*[a-zA-Z-]+(?=\s*:)"#, .keyword),
    ]
}
