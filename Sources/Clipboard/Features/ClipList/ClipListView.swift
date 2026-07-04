import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Root SwiftUI view hosted inside the Raycast-style NSPanel.
public struct ClipListView: View {
    @EnvironmentObject var env: AppEnvironment
    @StateObject private var vm: ClipListViewModel

    @State private var keyMonitor: Any?
    @State private var accessibilityTrusted: Bool = AccessibilityPermission.isTrusted

    public init(repository: ClipItemRepository) {
        _vm = StateObject(wrappedValue: ClipListViewModel(repository: repository))
    }

    public var body: some View {
        VStack(spacing: 0) {
            SearchBarView(text: $vm.query)

            filterChips
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

            Divider().opacity(0.4)

            HStack(spacing: 0) {
                itemList
                    .frame(minWidth: 300, idealWidth: 320, maxWidth: 340)
                Divider().opacity(0.4)
                ClipPreviewPane(item: vm.selectedItem)
            }

            if !accessibilityTrusted {
                accessibilityBanner
            }

            Divider().opacity(0.4)
            hintBar
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .task { vm.reload() }
        .onAppear {
            installKeyMonitor()
            accessibilityTrusted = AccessibilityPermission.isTrusted
        }
        .onDisappear { removeKeyMonitor() }
    }

    // MARK: - Filter chips

    @ViewBuilder private var filterChips: some View {
        HStack(spacing: 6) {
            ForEach(ClipFilter.allCases) { f in
                filterChip(f)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private func filterChip(_ f: ClipFilter) -> some View {
        let isActive = vm.filter == f
        HStack(spacing: 4) {
            Image(systemName: f.systemImage)
                .font(.system(size: 10, weight: .medium))
            Text(f.displayName)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(
                isActive
                    ? Color.accentColor.opacity(0.22)
                    : Color.secondary.opacity(0.10)
            )
        )
        .foregroundStyle(isActive ? Color.accentColor : .secondary)
        .contentShape(Capsule())
        .onTapGesture { vm.filter = f }
    }

    // MARK: - Item list

    @ViewBuilder private var itemList: some View {
        if vm.groups.allSatisfy({ $0.items.isEmpty }) {
            emptyState
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2, pinnedViews: [.sectionHeaders]) {
                        ForEach(vm.groups) { group in
                            if group.items.isEmpty { EmptyView() } else {
                                Section {
                                    ForEach(group.items) { item in
                                        row(for: item)
                                    }
                                } header: {
                                    if let title = group.title {
                                        groupHeader(title: title, count: group.items.count)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                }
                .onChange(of: vm.selectedID) { newID in
                    if let id = newID {
                        withAnimation(.easeOut(duration: 0.12)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
                .onChange(of: vm.filter) { _ in
                    if let id = vm.selectedID {
                        proxy.scrollTo(id, anchor: .top)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray").font(.system(size: 26)).foregroundStyle(.tertiary)
            Text(vm.query.isEmpty ? "No clips yet" : "No matches")
                .font(.system(size: 13, weight: .medium))
            Text(vm.query.isEmpty ? "Copy anything to get started."
                                   : "Try a different search.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func groupHeader(title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("\(count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 2)
        .background(Color.clear)
    }

    private func row(for item: ClipItem) -> some View {
        ClipRowView(item: item, isSelected: vm.selectedID == item.id)
            .id(item.id)
            .contentShape(Rectangle())
            .gesture(
                TapGesture(count: 2).onEnded {
                    vm.selectedID = item.id
                    paste(item, plain: false)
                }
                .exclusively(before:
                    TapGesture(count: 1).onEnded { vm.selectedID = item.id }
                )
            )
            .contextMenu { rowContextMenu(item) }
    }

    // MARK: - Context menu

    @ViewBuilder private func rowContextMenu(_ item: ClipItem) -> some View {
        Button("Paste") { paste(item, plain: false) }
        Button("Paste as plain text") { paste(item, plain: true) }
        Divider()
        Button(item.isPinned ? "Unpin" : "Pin") { vm.togglePin(item) }
        Button(item.isFavorited ? "Remove from favorites" : "Add to favorites") { vm.toggleFavorite(item) }
        Divider()
        Button("Copy again") {
            PasteboardWriter.write(item, to: .general)
        }
        Divider()
        Button("Delete", role: .destructive) { vm.delete(item) }
    }

    // MARK: - Accessibility banner

    private var accessibilityBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text("Accessibility not granted")
                    .font(.system(size: 11, weight: .semibold))
                Text("Enter and double-click will only copy — grant Accessibility to auto-paste.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open Settings…") {
                AccessibilityPermission.requestTrust()
                AccessibilityPermission.openSettings()
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.08))
    }

    // MARK: - Hint bar

    private var hintBar: some View {
        HStack(spacing: 14) {
            hint(key: "↩", label: "Paste")
            hint(key: "⇧↩", label: "Plain")
            hint(key: "⌘P", label: "Pin")
            hint(key: "⌘D", label: "Favorite")
            hint(key: "⌘⌫", label: "Delete")
            Spacer()
            hint(key: "⎋", label: "Close")
        }
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func hint(key: String, label: String) -> some View {
        HStack(spacing: 3) {
            Text(key)
                .font(.system(size: 9, weight: .semibold))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(label)
        }
    }

    // MARK: - Key monitor

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            let panelIsKey = (event.window as? PanelWindow) != nil
            if !panelIsKey { return event }
            return handle(event: event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let m = keyMonitor { NSEvent.removeMonitor(m) }
        keyMonitor = nil
    }

    /// Return `true` if we consumed the event.
    private func handle(event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let keyCode = Int(event.keyCode)

        switch keyCode {
        case kVK_UpArrow:   vm.moveSelection(.up); return true
        case kVK_DownArrow: vm.moveSelection(.down); return true
        case kVK_Home:      vm.moveSelection(.home); return true
        case kVK_End:       vm.moveSelection(.end); return true
        case kVK_Return:
            // Return = paste as-is; Shift+Return = force plain.
            if let item = vm.selectedItem {
                paste(item, plain: mods.contains(.shift))
            }
            return true
        case kVK_Escape:
            env.panelController.hide()
            return true
        default: break
        }

        // ⌘1..9 quick select + paste.
        if mods == .command,
           let chars = event.charactersIgnoringModifiers,
           let digit = Int(chars), digit >= 1, digit <= 9 {
            vm.selectByIndex(digit - 1)
            if let item = vm.selectedItem { paste(item, plain: false) }
            return true
        }

        // ⌘⌫ delete
        if keyCode == kVK_Delete, mods == .command {
            if let item = vm.selectedItem { vm.delete(item) }
            return true
        }
        // ⌘P pin
        if mods == .command, event.charactersIgnoringModifiers == "p" {
            if let item = vm.selectedItem { vm.togglePin(item) }
            return true
        }
        // ⌘D favorite
        if mods == .command, event.charactersIgnoringModifiers == "d" {
            if let item = vm.selectedItem { vm.toggleFavorite(item) }
            return true
        }

        return false
    }

    private func paste(_ item: ClipItem, plain: Bool) {
        env.panelController.pasteAndHide(item: item, preferPlainText: plain)
    }
}
