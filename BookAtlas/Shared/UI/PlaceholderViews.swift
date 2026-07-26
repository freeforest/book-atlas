import SwiftUI

struct PlaceholderPage<Content: View>: View {
    let section: AppSection
    let description: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: BookAtlasDesign.pageSpacing) {
            Text(section.title)
                .font(.title2.weight(.semibold))
                .accessibilityIdentifier(section.pageIdentifier)

            Text(description)
                .foregroundStyle(.secondary)

            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let symbolName: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbolName)
        } description: {
            Text(message)
        }
        .accessibilityIdentifier("empty-state")
    }
}

struct ErrorPlaceholderView: View {
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        }
        .accessibilityIdentifier("error-placeholder")
    }
}
