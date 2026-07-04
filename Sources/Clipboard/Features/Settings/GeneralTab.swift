import SwiftUI

struct GeneralTab: View {
    @EnvironmentObject var env: AppEnvironment
    @ObservedObject var settings = SettingsStore.shared
    @State private var launchEnabled: Bool = false
    @State private var launchError: String?

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { launchEnabled },
                    set: { newValue in
                        do {
                            try env.loginItemManager.setEnabled(newValue)
                            launchEnabled = env.loginItemManager.isEnabled
                            launchError = env.loginItemManager.lastRegisterError
                        } catch {
                            launchError = error.localizedDescription
                            launchEnabled = env.loginItemManager.isEnabled
                        }
                    }
                )) {
                    Text("Launch at login")
                }
                if let err = launchError {
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Startup")
            }

            Section {
                Picker("Appearance", selection: $settings.appearance) {
                    Text("System").tag(AppearancePreference.system)
                    Text("Light").tag(AppearancePreference.light)
                    Text("Dark").tag(AppearancePreference.dark)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Appearance")
            }

            Section {
                Toggle("Show icon in menu bar", isOn: $settings.showInMenuBar)
            } header: {
                Text("Menu Bar")
            }

            Section {
                LabeledContent("Accessibility") {
                    HStack {
                        Text(AccessibilityPermission.isTrusted ? "Granted" : "Not granted")
                            .foregroundStyle(AccessibilityPermission.isTrusted ? .green : .orange)
                        Spacer()
                        Button("Open System Settings…") {
                            AccessibilityPermission.openSettings()
                        }
                    }
                }
                Text("Required to auto-paste into other apps after selecting a clip.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } header: {
                Text("Permissions")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            launchEnabled = env.loginItemManager.isEnabled
            launchError = env.loginItemManager.lastRegisterError
        }
    }
}
