import Foundation

enum PythonGrammar {
    static let rules: [TokenRule] = [
        TokenRule(#"#[^\n]*"#, .comment),

        TokenRule(##"""[\s\S]*?""""##, .string),
        TokenRule(#"'''[\s\S]*?'''"#, .string),
        TokenRule(#""(?:\\.|[^"\\\n])*""#, .string),
        TokenRule(#"'(?:\\.|[^'\\\n])*'"#, .string),

        TokenRule(#"\b\d[\d_]*(?:\.[\d_]+)?(?:[eE][+-]?\d+)?\b"#, .number),

        TokenRule(#"\b[A-Z][A-Za-z0-9_]*\b"#, .type),

        TokenRule(#"""
        \b(?:False|None|True|and|as|assert|async|await|break|class|continue|def|del|elif|else|except|finally|for|from|global|if|import|in|is|lambda|nonlocal|not|or|pass|raise|return|try|while|with|yield|match|case|self|cls|print)\b
        """#, .keyword),
    ]
}
