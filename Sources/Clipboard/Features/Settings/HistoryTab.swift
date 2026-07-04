import SwiftUI

struct HistoryTab: View {
    @ObservedObject var settings = SettingsStore.shared
    @State private var newExcludeBundle: String = ""

    var body: some View {
        Form {
            Section {
                LabeledContent("Maximum items") {
                    HStack {
                        Slider(value: Binding(
                            get: { Double(settings.maxItems) },
                            set: { settings.maxItems = Int($0) }
                        ), in: 100...10_000, step: 100)
                        Text("\(settings.maxItems)")
                            .font(.system(size: 13, design: .monospaced))
                            .frame(minWidth: 60, alignment: .trailing)
                    }
                }
                LabeledContent("Retention (days)") {
                    HStack {
                        Slider(value: Binding(
                            get: { Double(settings.retentionDays) },
                            set: { settings.retentionDays = Int($0) }
                        ), in: 1...365, step: 1)
                        Text("\(settings.retentionDays)")
                            .font(.system(size: 13, design: .monospaced))
                            .frame(minWidth: 60, alignment: .trailing)
                    }
                }
                LabeledContent("Image storage (MB)") {
                    HStack {
                        Slider(value: Binding(
                            get: { Double(settings.imageQuotaMB) },
                            set: { settings.imageQuotaMB = Int($0) }
                        ), in: 50...5_000, step: 50)
                        Text("\(settings.imageQuotaMB)")
                            .font(.system(size: 13, design: .monospaced))
                            .frame(minWidth: 60, alignment: .trailing)
                    }
                }
            } header: {
                Text("Retention")
            }

            Section {
                Toggle("Ignore items marked as passwords", isOn: $settings.honorConcealedTypes)
                Text("Honors the org.nspasteboard convention used by 1Password, Bitwarden, and other password managers.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } header: {
                Text("Privacy")
            }

            Section {
                if settings.excludedBundleIds.isEmpty {
                    Text("No apps excluded")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(settings.excludedBundleIds).sorted(), id: \.self) { bundleId in
                        HStack {
                            Text(bundleId).font(.system(size: 12, design: .monospaced))
                            Spacer()
                            Button {
                                settings.excludedBundleIds.remove(bundleId)
                            } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                HStack {
                    TextField("com.example.app", text: $newExcludeBundle)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        let trimmed = newExcludeBundle.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        settings.excludedBundleIds.insert(trimmed)
                        newExcludeBundle = ""
                    }
                    .disabled(newExcludeBundle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("Excluded apps")
            } footer: {
                Text("Copies from these apps will not be captured.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
