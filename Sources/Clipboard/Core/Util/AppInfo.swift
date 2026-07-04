import Foundation

public enum AppInfo {
    public static let bundleIdentifier = "com.local.clipboard"
    public static let displayName = "Clipboard"

    /// `~/Library/Application Support/com.local.clipboard/`
    public static var applicationSupportDirectory: URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent(bundleIdentifier, isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}
