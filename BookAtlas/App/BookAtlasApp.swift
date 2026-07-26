import SwiftUI

@main
struct BookAtlasApp: App {
    @State private var navigation = AppNavigationState()

    var body: some Scene {
        WindowGroup {
            AppShellView(selection: $navigation.selection)
        }
        .defaultSize(width: 980, height: 620)
        .commands {
            BookAtlasCommands(selection: $navigation.selection)
        }
    }
}

struct BookAtlasCommands: Commands {
    @Binding var selection: AppSection

    var body: some Commands {
        CommandMenu("导航") {
            ForEach(Array(AppSection.allCases.enumerated()), id: \.element) {
                index, section in
                Button(section.title) {
                    selection = section
                }
                .keyboardShortcut(
                    KeyEquivalent(Character("\(index + 1)")),
                    modifiers: .command
                )
            }
        }
    }
}
