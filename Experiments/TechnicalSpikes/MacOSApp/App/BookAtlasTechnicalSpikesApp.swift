import SwiftUI

@main
struct BookAtlasTechnicalSpikesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandMenu("Experiment") {
                Button("Open File Panel") {
                    FileAccessProbe.presentOpenPanel()
                }
                .keyboardShortcut("o")
            }
        }
    }
}

