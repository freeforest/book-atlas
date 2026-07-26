import SwiftUI

struct TagsPlaceholderView: View {
    @ObservedObject var store: LibraryStore

    var body: some View {
        CatalogManagementView(store: store, initialSection: .tags, showsSectionPicker: false)
            .navigationTitle("标签")
            .accessibilityIdentifier("page-title-tags")
    }
}
