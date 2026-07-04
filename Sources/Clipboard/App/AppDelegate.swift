import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let environment = AppEnvironment()

    private var settingsWindowObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Accessory activation policy = no Dock icon, menu-bar-only app.
        NSApp.setActivationPolicy(.accessory)

        environment.start()

        // Ask macOS for Accessibility trust up front so Enter / double-click
        // paste actually posts ⌘V into the previous app. First run pops the
        // system dialog; subsequent runs are a no-op.
        if !AccessibilityPermission.isTrusted {
            AccessibilityPermission.requestTrust()
        }

        // Toggle Dock icon while Settings window is open so users get a Cmd-Tab entry.
        settingsWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { note in
            guard let window = note.object as? NSWindow,
                  window.identifier?.rawValue == "com_apple_SwiftUI_Settings_window" ||
                  window.title.localizedCaseInsensitiveContains("Settings") ||
                  window.title.localizedCaseInsensitiveContains("设置") else { return }
            NSApp.setActivationPolicy(.regular)
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { note in
            guard let window = note.object as? NSWindow else { return }
            let looksLikeSettings = window.title.localizedCaseInsensitiveContains("Settings") ||
                                    window.title.localizedCaseInsensitiveContains("设置") ||
                                    (window.identifier?.rawValue.contains("Settings") ?? false)
            if looksLikeSettings {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        environment.stop()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
