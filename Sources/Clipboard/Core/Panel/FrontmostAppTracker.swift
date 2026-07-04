import AppKit

/// Wraps `NSWorkspace.frontmostApplication` snapshotting so we can restore
/// focus to the user's previous app after the panel dismisses.
@MainActor
public final class FrontmostAppTracker {
    private(set) public var lastApp: NSRunningApplication?

    public init() {}

    public func snapshot() {
        // Ignore ourselves — otherwise re-showing the panel would try to
        // restore focus to Clipboard.
        let front = NSWorkspace.shared.frontmostApplication
        if front?.bundleIdentifier == AppInfo.bundleIdentifier { return }
        lastApp = front
    }

    public func restore() {
        guard let app = lastApp, !app.isTerminated else { return }
        app.activate(options: [])
    }
}
