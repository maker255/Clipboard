import SwiftUI

public struct TagEditorView: View {
    @EnvironmentObject var env: AppEnvironment

    public let item: ClipItem
    @State private var attached: [Tag] = []
    @State private var allTags: [Tag] = []
    @State private var newTagName: String = ""

    public init(item: ClipItem) { self.item = item }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tags")
                .font(.system(size: 13, weight: .semibold))
            if attached.isEmpty {
                Text("No tags on this clip.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(attached) { tag in
                        TagChipView(tag: tag) {
                            guard let id = tag.id, let itemId = item.id else { return }
                            try? env.repository.detach(tagId: id, from: itemId)
                            refresh()
                        }
                    }
                }
            }

            Divider()

            Text("Add tag")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack {
                TextField("Name", text: $newTagName)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    let trimmed = newTagName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty, let itemId = item.id else { return }
                    if let tag = try? env.repository.createOrGetTag(name: trimmed) {
                        try? env.repository.attach(tag: tag, to: itemId)
                    }
                    newTagName = ""
                    refresh()
                }
                .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if !allTags.isEmpty {
                Text("Existing")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                FlowLayout(spacing: 6) {
                    ForEach(allTags.filter { t in !attached.contains(where: { $0.id == t.id }) }) { tag in
                        Button {
                            guard let itemId = item.id else { return }
                            try? env.repository.attach(tag: tag, to: itemId)
                            refresh()
                        } label: {
                            TagChipView(tag: tag)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 300)
        .onAppear { refresh() }
    }

    private func refresh() {
        guard let itemId = item.id else { return }
        attached = (try? env.repository.tags(forItem: itemId)) ?? []
        allTags = (try? env.repository.allTags()) ?? []
    }
}

/// Minimal flow-layout used to lay out tag chips.
public struct FlowLayout: Layout {
    public var spacing: CGFloat
    public init(spacing: CGFloat = 6) { self.spacing = spacing }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for size in sizes {
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for (i, sub) in subviews.enumerated() {
            let size = sizes[i]
            if x + size.width > bounds.minX + maxWidth {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: .init(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
