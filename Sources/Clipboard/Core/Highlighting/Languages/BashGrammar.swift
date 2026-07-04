import Foundation

enum BashGrammar {
    static let rules: [TokenRule] = [
        TokenRule(#"#[^\n]*"#, .comment),

        TokenRule(#""(?:\\.|[^"\\\n])*""#, .string),
        TokenRule(#"'[^'\n]*'"#, .string),

        // $VAR / ${VAR}
        TokenRule(#"\$\{[^}]+\}"#, .type),
        TokenRule(#"\$\w+"#, .type),

        TokenRule(#"\b\d+\b"#, .number),

        TokenRule(#"""
        \b(?:if|then|else|elif|fi|for|do|done|while|until|case|esac|in|function|return|break|continue|exit|echo|export|source|alias|unset|local|readonly|declare|shift|test|true|false)\b
        """#, .keyword),
    ]
}
