import SwiftUI

@main
struct ClipboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.environment)
                .frame(minWidth: 560, minHeight: 420)
        }
        .windowResizability(.contentSize)
    }
}
