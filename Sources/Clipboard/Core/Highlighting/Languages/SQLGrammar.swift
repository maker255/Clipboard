import Foundation

enum SQLGrammar {
    static let rules: [TokenRule] = [
        TokenRule(#"--[^\n]*"#, .comment),
        TokenRule(#"/\*[\s\S]*?\*/"#, .comment),

        TokenRule(#"'(?:''|[^'\n])*'"#, .string),

        TokenRule(#"\b\d+(?:\.\d+)?\b"#, .number),

        TokenRule(#"""
        (?i)\b(?:SELECT|FROM|WHERE|INSERT|UPDATE|DELETE|CREATE|ALTER|DROP|TABLE|INDEX|VIEW|TRIGGER|JOIN|LEFT|RIGHT|INNER|OUTER|ON|AND|OR|NOT|NULL|IS|IN|EXISTS|LIKE|BETWEEN|GROUP|ORDER|BY|HAVING|LIMIT|OFFSET|UNION|AS|DISTINCT|CASE|WHEN|THEN|ELSE|END|VALUES|SET|INTO|DEFAULT|PRIMARY|KEY|FOREIGN|REFERENCES|UNIQUE|CHECK|CONSTRAINT|IF|WITH|BEGIN|COMMIT|ROLLBACK|TRANSACTION|AUTOINCREMENT|VIRTUAL)\b
        """#, .keyword),
    ]
}
