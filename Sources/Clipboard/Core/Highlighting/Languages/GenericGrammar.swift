import Foundation

/// Fallback rules for languages we haven't handwritten a grammar for
/// (Ruby, Go, Rust). Covers the universally-common tokens.
enum GenericGrammar {
    static let rules: [TokenRule] = [
        TokenRule(#"//[^\n]*"#, .comment),
        TokenRule(#"#[^\n]*"#, .comment),
        TokenRule(#"/\*[\s\S]*?\*/"#, .comment),

        TokenRule(#""(?:\\.|[^"\\\n])*""#, .string),
        TokenRule(#"'(?:\\.|[^'\\\n])*'"#, .string),
        TokenRule(#"`(?:\\.|[^`\\])*`"#, .string),

        TokenRule(#"\b\d[\d_]*(?:\.[\d_]+)?\b"#, .number),

        TokenRule(#"\b[A-Z][A-Za-z0-9_]*\b"#, .type),

        // Small superset of common keywords across Go/Rust/Ruby.
        TokenRule(#"""
        \b(?:func|fn|def|end|do|if|else|elif|then|case|when|switch|return|break|continue|for|while|loop|match|let|mut|const|var|type|struct|enum|impl|trait|interface|package|import|use|from|as|class|module|require|include|self|nil|true|false|null|new|go|defer|chan|select|make|map|range|pub|mod|extern|move|async|await|yield|throw|throws|try|catch|finally)\b
        """#, .keyword),
    ]
}
