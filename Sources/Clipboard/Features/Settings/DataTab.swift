import AppKit
import SwiftUI

struct DataTab: View {
    @EnvironmentObject var env: AppEnvironment

    var body: some View {
        Form {
            Section {
                LabeledContent("Storage location") {
                    HStack {
                        Text(env.fileStore.rootURL.path)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button("Reveal in Finder…") {
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: env.fileStore.rootURL.path)
                        }
                    }
                }
            } header: {
                Text("Storage")
            }

            Section {
                Button("Clear all history…", role: .destructive) {
                    let alert = NSAlert()
                    alert.messageText = "Clear all clipboard history?"
                    alert.informativeText = "This cannot be undone. Pinned and favorited items will also be removed."
                    alert.alertStyle = .critical
                    alert.addButton(withTitle: "Clear")
                    alert.addButton(withTitle: "Cancel")
                    if alert.runModal() == .alertFirstButtonReturn {
                        try? env.repository.deleteAll()
                        // Wipe on-disk artifacts too.
                        let fm = FileManager.default
                        for dir in [env.fileStore.imagesDir, env.fileStore.thumbsDir, env.fileStore.attributedDir] {
                            if let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                                for url in contents { try? fm.removeItem(at: url) }
                            }
                        }
                    }
                }
            } header: {
                Text("Danger Zone")
            }

            Section {
                Text("About")
                    .font(.system(size: 13, weight: .semibold))
                Text("Clipboard \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0")")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("Built with SwiftUI + GRDB.swift. Local-first, non-sandboxed.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
    }
}
