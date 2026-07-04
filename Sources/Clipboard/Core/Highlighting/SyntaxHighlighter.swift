import AppKit
import Foundation
import SwiftUI

public enum TokenStyle: String {
    case keyword, string, number, comment, type, plain
}

public struct TokenRule {
    public let pattern: NSRegularExpression
    public let style: TokenStyle
    public init(_ pattern: String, _ style: TokenStyle) {
        // options: allow multiline/dotAll where useful; individual patterns
        // handle their own line anchors.
        self.pattern = try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
        self.style = style
    }
}

/// Applies a language's TokenRules to build an `AttributedString`.
///
/// Rendering strategy: iterate rules in priority order (comments first so they
/// win over keywords). Later matches never overwrite earlier ones.
public enum SyntaxHighlighter {
    public static func highlight(_ text: String, language: CodeLanguage?) -> AttributedString {
        var attr = AttributedString(text)
        // Default: monospaced body font, semantic foreground.
        attr.font = .system(.body, design: .monospaced)
        attr.foregroundColor = .primary

        guard let language else { return attr }
        let rules = grammar(for: language)
        guard !rules.isEmpty else { return attr }

        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        var claimed = IndexSet()

        for rule in rules {
            let matches = rule.pattern.matches(in: text, options: [], range: range)
            for m in matches {
                let r = m.range
                if r.location == NSNotFound { continue }
                // Skip if any part already claimed.
                let indices = IndexSet(integersIn: r.location..<(r.location + r.length))
                if !indices.isDisjoint(with: claimed) { continue }
                claimed.formUnion(indices)

                if let swiftRange = Range(r, in: text),
                   let attrRange = Range(swiftRange, in: attr) {
                    attr[attrRange].foregroundColor = color(for: rule.style)
                }
            }
        }
        return attr
    }

    // MARK: - Colors

    /// Uses `NSColor` semantic system colors so the palette adapts to light/dark
    /// without needing a compiled asset catalog (which requires actool / Xcode).
    private static func color(for style: TokenStyle) -> Color {
        switch style {
        case .keyword: return Color(nsColor: .systemPurple)
        case .string:  return Color(nsColor: .systemRed)
        case .number:  return Color(nsColor: .systemBlue)
        case .comment: return Color(nsColor: .secondaryLabelColor)
        case .type:    return Color(nsColor: .systemTeal)
        case .plain:   return .primary
        }
    }

    // MARK: - Grammar dispatch

    private static func grammar(for lang: CodeLanguage) -> [TokenRule] {
        switch lang {
        case .swift:       return SwiftGrammar.rules
        case .javascript,
             .typescript:  return JSGrammar.rules
        case .python:      return PythonGrammar.rules
        case .json:        return JSONGrammar.rules
        case .bash:        return BashGrammar.rules
        case .html,
             .xml:         return HTMLGrammar.rules
        case .css:         return CSSGrammar.rules
        case .sql:         return SQLGrammar.rules
        case .yaml:        return YAMLGrammar.rules
        case .ruby,
             .go,
             .rust:        return GenericGrammar.rules
        }
    }
}
