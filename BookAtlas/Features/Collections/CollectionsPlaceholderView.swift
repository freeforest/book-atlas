import SwiftUI

struct CollectionsPlaceholderView: View {
    @ObservedObject var store: LibraryStore

    var body: some View {
        CatalogManagementView(store: store, initialSection: .collections, showsSectionPicker: false)
            .navigationTitle("书单")
    }
}
