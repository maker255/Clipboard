import SwiftUI

struct HotkeysTab: View {
    @EnvironmentObject var env: AppEnvironment
    @ObservedObject var settings = SettingsStore.shared

    @State private var recording = false
    @State private var recorder = HotkeyRecorder()

    var body: some View {
        Form {
            Section {
                LabeledContent("Open panel") {
                    HStack(spacing: 8) {
                        Text(displayString)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(recording ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.15))
                            )
                        Button(recording ? "Recording… (Esc to cancel)" : "Record…") {
                            if recording { recorder.stop(); recording = false } else { startRecording() }
                        }
                        Button("Reset") {
                            settings.updateOpenPanelHotkey(.defaultOpenPanel)
                            env.reregisterOpenPanelHotkey()
                        }
                    }
                }
                Text("Default: ⌥V. Overrides the system ◊ shortcut on US layouts. Registered globally via Carbon — press any combination with at least one modifier to rebind.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } header: {
                Text("Global Hotkeys")
            }

            Section {
                LabeledContent("Paste selected", value: "Return")
                LabeledContent("Paste with formatting", value: "⇧Return")
                LabeledContent("Focus search", value: "⌘F")
                LabeledContent("Pin / unpin", value: "⌘P")
                LabeledContent("Favorite / unfavorite", value: "⌘D")
                LabeledContent("Delete", value: "⌘⌫")
                LabeledContent("Quick select", value: "⌘1 – ⌘9")
                LabeledContent("Close panel", value: "Esc")
            } header: {
                Text("In-panel Shortcuts")
            }
        }
        .formStyle(.grouped)
        .onDisappear { recorder.stop(); recording = false }
    }

    private var displayString: String {
        KeyCodes.displayName(
            keyCode: settings.openPanelHotkey.keyCode,
            carbon: settings.openPanelHotkey.carbonModifiers
        )
    }

    private func startRecording() {
        recording = true
        recorder.start(
            onCaptured: { binding in
                settings.updateOpenPanelHotkey(binding)
                env.reregisterOpenPanelHotkey()
                recording = false
            },
            onCanceled: { recording = false }
        )
    }
}
