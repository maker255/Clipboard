import Foundation

/// Small heuristic classifier for a handful of popular languages.
///
/// Returns the winner if its score meets `threshold`; otherwise `nil`.
/// Callers should treat a `nil` result as "not detectably code".
public enum CodeLanguage: String, CaseIterable, Codable {
    case swift, javascript, typescript, python, json, bash, html
    case xml, css, sql, yaml, ruby, go, rust
}

public enum LanguageDetector {
    private static let threshold = 3

    public static func detect(_ text: String) -> CodeLanguage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // Fast JSON detection — the parser is decisive.
        if let start = trimmed.first, start == "{" || start == "[",
           let data = trimmed.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return .json
        }

        var scores: [CodeLanguage: Int] = [:]
        for lang in CodeLanguage.allCases {
            scores[lang] = score(text: trimmed, for: lang)
        }
        let best = scores.max { $0.value < $1.value }
        guard let (lang, score) = best, score >= threshold else { return nil }
        return lang
    }

    // MARK: - Grammar signatures

    private static func score(text: String, for lang: CodeLanguage) -> Int {
        switch lang {
        case .swift:
            return count(text, patterns: [
                #"\bfunc\s+\w+\s*\("#,
                #"\b(let|var)\s+\w+"#,
                #"\bimport\s+(Foundation|SwiftUI|AppKit|Combine|UIKit)\b"#,
                #"\bguard\s+let\b"#,
                #"->\s*\S+"#,
                #"@(objc|MainActor|Published|State|Binding|Environment|ObservedObject|StateObject)"#,
            ])
        case .javascript:
            return count(text, patterns: [
                #"\bfunction\s+\w+\s*\("#,
                #"\b(const|let|var)\s+\w+\s*="#,
                #"=>"#,
                #"\bimport\s+.+\s+from\s+['"]"#,
                #"\bconsole\.\w+"#,
                #"\brequire\(['"]"#,
            ])
        case .typescript:
            return count(text, patterns: [
                #":\s*(string|number|boolean|void|any|unknown|never)\b"#,
                #"\binterface\s+\w+"#,
                #"\btype\s+\w+\s*="#,
                #"\bimport\s+.+\s+from\s+['"]"#,
                #"\bexport\s+(default|const|function|class)"#,
            ])
        case .python:
            return count(text, patterns: [
                #"(?m)^\s*def\s+\w+\s*\("#,
                #"(?m)^\s*import\s+\w+"#,
                #"(?m)^\s*from\s+\w+\s+import\b"#,
                #"(?m)^\s*class\s+\w+\s*[(:]"#,
                #":\s*$"#,
                #"\bprint\s*\("#,
                #"\bself\."#,
            ])
        case .json:
            return count(text, patterns: [
                #"^\s*\{"#, #"^\s*\["#, #""[^"]+"\s*:"#,
            ])
        case .bash:
            return count(text, patterns: [
                #"(?m)^\s*#!\s*/\S*(bash|sh|zsh)"#,
                #"(?m)^\s*(if|for|while|case|function)\b"#,
                #"\$\{?\w+\}?"#,
                #"(?m)^\s*(echo|export|source|alias)\b"#,
            ])
        case .html:
            return count(text, patterns: [
                #"<!DOCTYPE\s+html"#, #"<html\b"#, #"<body\b"#, #"<div\b"#, #"<script\b"#,
                #"</\w+>"#,
            ])
        case .xml:
            return count(text, patterns: [
                #"<\?xml\b"#, #"<\w+:\w+\b"#, #"</\w+>"#,
            ])
        case .css:
            return count(text, patterns: [
                #"[.#]?\w[\w-]*\s*\{[^{}]*\}"#,
                #"@(media|import|keyframes|font-face)\b"#,
                #":\s*(rgba?|hsla?|#[0-9a-fA-F]{3,8})\("#,
            ])
        case .sql:
            return count(text, patterns: [
                #"(?i)\bSELECT\b.*\bFROM\b"#,
                #"(?i)\b(INSERT|UPDATE|DELETE|CREATE|ALTER|DROP)\b"#,
                #"(?i)\b(WHERE|JOIN|GROUP\s+BY|ORDER\s+BY)\b"#,
            ])
        case .yaml:
            return count(text, patterns: [
                #"(?m)^\s*[\w-]+:\s*(\S.*)?$"#,
                #"(?m)^---\s*$"#,
                #"(?m)^\s*-\s+\S"#,
            ])
        case .ruby:
            return count(text, patterns: [
                #"(?m)^\s*def\s+\w+"#,
                #"(?m)^\s*end\s*$"#,
                #"\brequire\s+['"]"#,
                #"\bputs\s+"#,
            ])
        case .go:
            return count(text, patterns: [
                #"\bpackage\s+\w+"#,
                #"\bfunc\s+\w+\s*\("#,
                #"\bimport\s+\("#,
                #":="#,
                #"\bfmt\.\w+\("#,
            ])
        case .rust:
            return count(text, patterns: [
                #"\bfn\s+\w+\s*\("#,
                #"\blet\s+mut\s+\w+"#,
                #"\bimpl\s+\w+"#,
                #"::<[^>]+>"#,
                #"\buse\s+\w+::"#,
            ])
        }
    }

    private static func count(_ text: String, patterns: [String]) -> Int {
        var s = 0
        for p in patterns where text.range(of: p, options: .regularExpression) != nil {
            s += 1
        }
        return s
    }
}
