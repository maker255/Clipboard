import AppKit
import Combine
import Foundation

public enum ClipFilter: String, CaseIterable, Identifiable {
    case all
    case pinned
    case favorites
    case images
    case files
    case code

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .all:        return "All"
        case .pinned:     return "Pinned"
        case .favorites:  return "Favorites"
        case .images:     return "Images"
        case .files:      return "Files"
        case .code:       return "Code"
        }
    }

    public var systemImage: String {
        switch self {
        case .all:        return "square.grid.2x2"
        case .pinned:     return "pin.fill"
        case .favorites:  return "star.fill"
        case .images:     return "photo"
        case .files:      return "doc"
        case .code:       return "chevron.left.forwardslash.chevron.right"
        }
    }
}

/// One visual section in the list. Under `.all` we split into Pinned + Recent;
/// every other filter renders as a single unnamed section.
public struct ClipGroup: Identifiable, Equatable {
    public let id: String
    public let title: String?
    public let items: [ClipItem]
}

@MainActor
public final class ClipListViewModel: ObservableObject {
    @Published public var query: String = ""
    @Published public var filter: ClipFilter = .all
    @Published public var groups: [ClipGroup] = []
    @Published public var selectedID: Int64?

    /// Flat view of all items in current groups, in visual order. Used for
    /// keyboard navigation and index-based quick-select.
    public var allItems: [ClipItem] { groups.flatMap { $0.items } }

    public var selectedItem: ClipItem? {
        guard let id = selectedID else { return nil }
        return allItems.first { $0.id == id }
    }

    private let repository: ClipItemRepository
    private var cancellables = Set<AnyCancellable>()
    private var searchDebounce = Debouncer(delay: 0.12)

    public init(repository: ClipItemRepository) {
        self.repository = repository

        repository.changesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.reload() }
            .store(in: &cancellables)

        $query
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                self?.searchDebounce.call { [weak self] in
                    Task { @MainActor in self?.reload() }
                }
            }
            .store(in: &cancellables)

        $filter
            .removeDuplicates()
            .dropFirst()
            // @Published emits on willSet, so self.filter still holds the OLD
            // value inside this sink — pass the emitted value through instead.
            .sink { [weak self] newFilter in self?.reload(filter: newFilter, resetSelection: true) }
            .store(in: &cancellables)
    }

    public func reload(filter overrideFilter: ClipFilter? = nil, resetSelection: Bool = false) {
        let filter = overrideFilter ?? self.filter
        do {
            let trimmed = query.trimmingCharacters(in: .whitespaces)
            let q: String? = trimmed.isEmpty ? nil : query

            let items: [ClipItem]
            switch filter {
            case .all:       items = try repository.fetch(query: q, limit: 500)
            case .pinned:    items = try repository.fetch(pinnedOnly: true, query: q, limit: 500)
            case .favorites: items = try repository.fetch(favoritedOnly: true, query: q, limit: 500)
            case .images:    items = try repository.fetch(kinds: [.image], query: q, limit: 500)
            case .files:     items = try repository.fetch(kinds: [.file], query: q, limit: 500)
            case .code:      items = try repository.fetch(kinds: [.code, .markdown], query: q, limit: 500)
            }

            let groups: [ClipGroup]
            switch filter {
            case .all:
                let pinned = items.filter { $0.isPinned }
                let rest   = items.filter { !$0.isPinned }
                var sections: [ClipGroup] = []
                if !pinned.isEmpty {
                    sections.append(ClipGroup(id: "pinned", title: "Pinned", items: pinned))
                }
                sections.append(ClipGroup(
                    id: "recent",
                    title: pinned.isEmpty ? nil : "Recent",
                    items: rest
                ))
                groups = sections
            default:
                // Distinct group id per filter so SwiftUI rebuilds the section
                // instead of diffing items across two different filters.
                groups = [ClipGroup(id: "flat-\(filter.rawValue)", title: nil, items: items)]
            }
            self.groups = groups

            let flat = groups.flatMap { $0.items }
            if resetSelection {
                selectedID = flat.first?.id
            } else if selectedID == nil || !flat.contains(where: { $0.id == selectedID }) {
                selectedID = flat.first?.id
            }
        } catch {
            Log.database.error("Reload failed: \(String(describing: error))")
            groups = []
            selectedID = nil
        }
    }

    // MARK: - Navigation

    public enum Direction { case up, down, home, end }

    public func moveSelection(_ direction: Direction) {
        let flat = allItems
        guard !flat.isEmpty else { return }
        if let current = selectedID, let idx = flat.firstIndex(where: { $0.id == current }) {
            let next: Int
            switch direction {
            case .up:   next = max(0, idx - 1)
            case .down: next = min(flat.count - 1, idx + 1)
            case .home: next = 0
            case .end:  next = flat.count - 1
            }
            selectedID = flat[next].id
        } else {
            selectedID = flat.first?.id
        }
    }

    public func selectByIndex(_ zeroBasedIndex: Int) {
        let flat = allItems
        guard zeroBasedIndex >= 0, zeroBasedIndex < flat.count else { return }
        selectedID = flat[zeroBasedIndex].id
    }

    // MARK: - Mutations

    public func togglePin(_ item: ClipItem) {
        guard let id = item.id else { return }
        try? repository.setPinned(!item.isPinned, id: id)
    }

    public func toggleFavorite(_ item: ClipItem) {
        guard let id = item.id else { return }
        try? repository.setFavorited(!item.isFavorited, id: id)
    }

    public func delete(_ item: ClipItem) {
        guard let id = item.id else { return }
        try? repository.delete(id: id)
    }
}
