import CryptoKit
import Foundation

public enum Hashing {
    /// Canonical SHA-256 for a text clip: trims whitespace, then hashes UTF-8 bytes.
    public static func text(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return sha256(Data(trimmed.utf8))
    }

    /// For images: hash the exact bytes we intend to persist to disk (PNG-encoded).
    public static func data(_ d: Data) -> String { sha256(d) }

    /// For file references: hash the sorted list of absolute URL strings.
    public static func files(_ urls: [URL]) -> String {
        let joined = urls.map(\.absoluteString).sorted().joined(separator: "\n")
        return sha256(Data(joined.utf8))
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
