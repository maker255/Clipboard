import Foundation

enum JSGrammar {
    static let rules: [TokenRule] = [
        TokenRule(#"//[^\n]*"#, .comment),
        TokenRule(#"/\*[\s\S]*?\*/"#, .comment),

        TokenRule(#""(?:\\.|[^"\\\n])*""#, .string),
        TokenRule(#"'(?:\\.|[^'\\\n])*'"#, .string),
        TokenRule(#"`(?:\\.|[^`\\])*`"#, .string),

        TokenRule(#"\b\d[\d_]*(?:\.[\d_]+)?(?:[eE][+-]?\d+)?\b"#, .number),

        TokenRule(#"\b[A-Z][A-Za-z0-9_]*\b"#, .type),

        TokenRule(#"""
        \b(?:abstract|arguments|await|boolean|break|byte|case|catch|char|class|const|continue|debugger|default|delete|do|double|else|enum|eval|export|extends|false|final|finally|float|for|from|function|goto|if|implements|import|in|instanceof|int|interface|let|long|native|new|null|of|package|private|protected|public|return|short|static|super|switch|synchronized|this|throw|throws|transient|true|try|typeof|undefined|var|void|volatile|while|with|yield|as|async|namespace|type|readonly|declare|is|keyof)\b
        """#, .keyword),
    ]
}
