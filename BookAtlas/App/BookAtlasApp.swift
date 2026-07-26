import SwiftUI

@main
struct BookAtlasApp: App {
    @State private var navigation = AppNavigationState()
    @StateObject private var libraryStore: LibraryStore

    init() {
        _libraryStore = StateObject(wrappedValue: LibraryStore.makeApplicationStore())
    }

    var body: some Scene {
        WindowGroup {
            AppShellView(selection: $navigation.selection, libraryStore: libraryStore)
        }
        .defaultSize(width: 980, height: 620)
        .commands {
            BookAtlasCommands(selection: $navigation.selection, libraryStore: libraryStore)
        }
    }
}

struct BookAtlasCommands: Commands {
    @Binding var selection: AppSection
    @ObservedObject var libraryStore: LibraryStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("新增书籍") {
                selection = .library
                libraryStore.beginCreate()
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        CommandGroup(replacing: .saveItem) {
            Button("保存书籍") {
                libraryStore.requestSaveEditor()
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(libraryStore.editorSession == nil)
        }

        CommandMenu("书籍") {
            Button("编辑所选书籍") {
                selection = .library
                libraryStore.beginEdit()
            }
            .disabled(selection != .library || !libraryStore.hasSelection)

            Button("删除所选书籍") {
                libraryStore.beginDelete()
            }
            .keyboardShortcut(.delete, modifiers: [])
            .disabled(selection != .library || !libraryStore.hasSelection)
        }

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
