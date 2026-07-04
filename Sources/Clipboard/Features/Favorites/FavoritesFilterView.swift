import SwiftUI

/// Currently the "Favorites" filter is expressed as a `ClipFilter.favorites`
/// chip in `ClipListView`. This file is a placeholder for future sidebar-style
/// affordances (e.g. a separate favorites hoisting on the left rail).
public struct FavoritesFilterView: View {
    @Binding public var filter: ClipFilter
    public init(filter: Binding<ClipFilter>) { self._filter = filter }

    public var body: some View {
        EmptyView()
    }
}
