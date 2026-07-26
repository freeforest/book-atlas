import SwiftUI

struct FictionalBook: Identifiable, Hashable {
    let id: String
    let title: String
    let author: String

    static let all = [
        FictionalBook(id: "mist", title: "雾港档案", author: "林汐远"),
        FictionalBook(id: "garden", title: "机器与花园", author: "周弦"),
        FictionalBook(id: "stars", title: "星图索引", author: "许澄野")
    ]
}

struct ContentView: View {
    @State private var query = ""
    @State private var selection: FictionalBook.ID?

    private var filteredBooks: [FictionalBook] {
        guard !query.isEmpty else { return FictionalBook.all }
        return FictionalBook.all.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.author.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationSplitView {
            List(filteredBooks, selection: $selection) { book in
                Text(book.title)
                    .tag(book.id)
            }
            .navigationTitle("虚构书库")
        } content: {
            Table(filteredBooks, selection: $selection) {
                TableColumn("标题", value: \.title)
                TableColumn("作者", value: \.author)
            }
        } detail: {
            VStack(spacing: 16) {
                Text(selection ?? "未选择虚构图书")
                    .accessibilityIdentifier("selection-status")
                AppKitStatusView()
                Button("Choose Test File") {
                    FileAccessProbe.presentOpenPanel()
                }
                .accessibilityIdentifier("choose-file")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .searchable(text: $query, prompt: "搜索虚构图书")
        .toolbar {
            ToolbarItem {
                Button("Open File Panel") {
                    FileAccessProbe.presentOpenPanel()
                }
                .accessibilityIdentifier("toolbar-open-file")
            }
        }
    }
}

