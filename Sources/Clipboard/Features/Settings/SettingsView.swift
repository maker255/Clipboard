import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject var env: AppEnvironment

    public init() {}

    public var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            HotkeysTab()
                .tabItem { Label("Hotkeys", systemImage: "keyboard") }
            HistoryTab()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            DataTab()
                .tabItem { Label("Data", systemImage: "internaldrive") }
        }
        .padding(20)
        .frame(width: 560)
        .environmentObject(env)
    }
}
