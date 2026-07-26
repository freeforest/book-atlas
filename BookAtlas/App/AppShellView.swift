import SwiftUI

struct AppShellView: View {
    @Binding var selection: AppSection

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(AppSection.allCases) { section in
                    Label(section.title, systemImage: section.symbolName)
                        .tag(section)
                        .accessibilityIdentifier(section.navigationIdentifier)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Book Atlas")
            .accessibilityIdentifier("app-sidebar")
        } detail: {
            page(for: selection)
                .frame(
                    minWidth: BookAtlasDesign.minimumContentWidth,
                    minHeight: BookAtlasDesign.minimumContentHeight
                )
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(selection.title)
                    .font(.headline)
                    .accessibilityIdentifier("toolbar-title")
            }

            ToolbarItem(placement: .primaryAction) {
                Menu("导航", systemImage: "sidebar.left") {
                    ForEach(AppSection.allCases) { section in
                        Button(section.title) {
                            selection = section
                        }
                    }
                }
                .accessibilityLabel("页面导航")
            }
        }
        .searchable(
            text: .constant(""),
            placement: .toolbar,
            prompt: "搜索书库（即将推出）"
        )
        .accessibilityIdentifier("app-shell")
    }

    @ViewBuilder
    private func page(for section: AppSection) -> some View {
        switch section {
        case .library:
            LibraryPlaceholderView()
        case .collections:
            CollectionsPlaceholderView()
        case .tags:
            TagsPlaceholderView()
        case .graph:
            GraphPlaceholderView()
        case .settings:
            SettingsPlaceholderView()
        }
    }
}
